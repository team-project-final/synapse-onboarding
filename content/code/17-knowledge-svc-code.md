---
title: knowledge-svc 샘플 코드
---

# knowledge-svc 샘플 코드

> 스택(doc 18 기준): Java 21 · Spring Boot 4 · Spring Data JPA/**Hibernate 7**(`@TenantId`) · PostgreSQL+**pgvector** · Elasticsearch · S3 · Kafka(Outbox).

## 기능 정의 → 구현 매핑

| 기능 | 구현 포인트 |
|---|---|
| 노트 CRUD + 멀티테넌시 | `@TenantId` 엔티티 + `JpaRepository` |
| 위키링크 `[[ ]]` | 정규식 파서 → `note_links` 동기화 |
| 전문 검색 | Native `tsvector`(또는 Elasticsearch) |
| 시맨틱 검색 | pgvector `<=>` 코사인 거리 Native Query |
| 첨부 업로드 | S3 Presigned PUT URL(서버 미경유) |

## 1. 노트 엔티티 + 리포지토리 (Hibernate 7 `@TenantId`)

```java
@Entity
@Table(name = "notes",
       indexes = @Index(name = "idx_notes_tenant_author", columnList = "tenant_id, author_id"))
public class Note {
    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)   // UUID v7
    private UUID id;

    @Column(nullable = false, length = 500)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String content;

    @TenantId                                          // Hibernate가 모든 쿼리에 tenant_id 자동 필터
    @Column(name = "tenant_id", nullable = false, updatable = false)
    private UUID tenantId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id")
    private User author;

    @CreationTimestamp private Instant createdAt;
    @UpdateTimestamp   private Instant updatedAt;
}

public interface NoteRepository extends JpaRepository<Note, UUID> {
    Page<Note> findByAuthorIdOrderByUpdatedAtDesc(UUID authorId, Pageable pageable);

    @Query(value = """
        SELECT * FROM notes
        WHERE tenant_id = :tenantId
          AND to_tsvector('korean', title || ' ' || COALESCE(content, ''))
              @@ plainto_tsquery('korean', :q)
        ORDER BY ts_rank(to_tsvector('korean', title || ' ' || COALESCE(content,'')),
                         plainto_tsquery('korean', :q)) DESC
        """, nativeQuery = true)
    List<Note> fullTextSearch(@Param("tenantId") UUID tenantId, @Param("q") String query);
}
```

## 2. 위키링크 파싱 → note_links 동기화

```java
@Component
public class WikiLinkParser {                 // WikiLinkParserPort 구현
    private static final Pattern LINK = Pattern.compile("\\[\\[([^\\]]+)\\]\\]");

    public Set<String> extractTargets(String markdown) {
        Set<String> targets = new LinkedHashSet<>();
        Matcher m = LINK.matcher(markdown);
        while (m.find()) targets.add(m.group(1).trim());   // [[노트 제목]] → "노트 제목"
        return targets;
    }
}

@Service
@RequiredArgsConstructor
public class NoteService {
    private final NoteRepository notes;
    private final NoteLinkRepository links;
    private final WikiLinkParser parser;
    private final NoteEventPublisher events;   // Outbox → Kafka

    @Transactional
    public Note save(UUID authorId, SaveNoteCommand cmd) {
        Note note = notes.save(Note.of(authorId, cmd));
        // 위키링크 재동기화
        links.deleteBySourceNoteId(note.getId());
        for (String target : parser.extractTargets(cmd.content())) {
            notes.findByTitle(target).ifPresent(t ->
                links.save(new NoteLink(note.getId(), t.getId())));
        }
        events.publish(new NoteCreated(note.getId(), authorId, note.getTenantId()));  // chunking·ES·게임화가 소비
        return note;
    }
}
```

## 3. pgvector 시맨틱 검색 (코사인 거리 `<=>`)

```java
public interface NoteChunkRepository extends JpaRepository<NoteChunk, UUID> {
    @Query(value = """
        SELECT nc.* FROM note_chunks nc
        JOIN notes n ON n.id = nc.note_id
        WHERE n.tenant_id = :tenantId AND n.deleted_at IS NULL
        ORDER BY nc.embedding <=> CAST(:queryVec AS vector)   -- HNSW 인덱스 사용
        LIMIT :k
        """, nativeQuery = true)
    List<NoteChunk> searchSimilar(@Param("tenantId") UUID tenantId,
                                  @Param("queryVec") String queryVector,  // "[0.1,0.2,...]"
                                  @Param("k") int k);
}
```
> 임베딩 *계산*은 이 서비스가 하지 않습니다 — learning-ai가 gRPC로 채워준 `embedding` 컬럼을 검색만 합니다.

## 4. S3 Presigned URL (첨부 업로드)

```java
@Component
@RequiredArgsConstructor
public class S3AttachmentAdapter implements ObjectStoragePort {
    private final S3Presigner presigner;     // AWS SDK v2

    @Override
    public URL presignUpload(UUID tenantId, UUID noteId, String filename) {
        String key = "%s/%s/%s/%s".formatted(tenantId, noteId, UUID.randomUUID(), filename);
        var put = PutObjectRequest.builder().bucket("synapse-attachments-prod").key(key).build();
        var req = PutObjectPresignRequest.builder()
            .signatureDuration(Duration.ofMinutes(15))
            .putObjectRequest(put).build();
        return presigner.presignPutObject(req).url();   // 클라이언트가 S3로 직접 업로드
    }
}
```

---
*근거: doc 18 §4.1.4 JPA/Hibernate 7 · §5.1.2 pgvector · §5.7 S3 · synapse-knowledge-svc ARCHITECTURE. 서비스 기능 전체는 [12. knowledge-svc 상세].*
