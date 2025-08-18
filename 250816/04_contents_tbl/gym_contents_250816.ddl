-- =========================================================
-- 🔧 공통: 스키마 고정(DDL에 스키마 접두어가 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 1) contents_tbl 생성  ← 작성자(member_id)는 관리자만 허용
--------------------------------------------------------------------------------
-- DROP TABLE contents_tbl CASCADE CONSTRAINTS;  -- 필요시 초기화용

CREATE TABLE contents_tbl (
    content_id         NUMBER          NOT NULL,                 -- 콘텐츠 고유 ID (PK)
    content_title      VARCHAR2(100)   NOT NULL,                 -- 콘텐츠 제목
    content_content    CLOB,                                     -- HTML 본문
    member_id          VARCHAR2(20)    NOT NULL,                 -- 작성자(관리자 계정) FK
    content_reg_date   DATE            DEFAULT SYSDATE,          -- 작성일(기본값 SYSDATE)
    content_mod_date   DATE,                                     -- 수정일(UPDATE 때만 자동 세팅, INSERT 시 NULL)
    content_use        CHAR(1)         DEFAULT 'Y' NOT NULL      -- 사용여부('Y','N') 기본 'Y'
);

-- 📌 컬럼 주석(엑셀 정의 반영)
COMMENT ON COLUMN contents_tbl.content_id       IS '콘텐츠 고유 ID';
COMMENT ON COLUMN contents_tbl.content_title    IS '콘텐츠 제목 (예: 오시는 길 등)';
COMMENT ON COLUMN contents_tbl.content_content  IS 'HTML 내용';
COMMENT ON COLUMN contents_tbl.member_id        IS '등록자 (관리자)';
COMMENT ON COLUMN contents_tbl.content_reg_date IS '작성일';
COMMENT ON COLUMN contents_tbl.content_mod_date IS '수정일 (UPDATE 시 자동 기록, INSERT 시 NULL)';
COMMENT ON COLUMN contents_tbl.content_use      IS '사용여부(기본값 ''Y'')';

-- 📌 제약조건
ALTER TABLE contents_tbl ADD CONSTRAINT contents_tbl_pk PRIMARY KEY (content_id);         -- PK
ALTER TABLE contents_tbl ADD CONSTRAINT content_use_ch CHECK (content_use IN ('Y','N'));  -- Y/N 체크

--------------------------------------------------------------------------------
-- 2) FK: 작성자 → member_tbl.member_id
--------------------------------------------------------------------------------
ALTER TABLE contents_tbl
  ADD CONSTRAINT fk_contents_member
  FOREIGN KEY (member_id)
  REFERENCES member_tbl(member_id);

--------------------------------------------------------------------------------
-- 3) 트리거 #1: 작성자는 반드시 '관리자' 계정만 허용 (member_role='ADMIN')
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_contents_writer_admin';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -4080 THEN RAISE; END IF;  -- ORA-04080: 존재하지 않음 → 무시
END;
/

CREATE OR REPLACE TRIGGER trg_contents_writer_admin
BEFORE INSERT OR UPDATE ON contents_tbl
FOR EACH ROW
DECLARE
    v_role member_tbl.member_role%TYPE;
BEGIN
    SELECT member_role
      INTO v_role
      FROM member_tbl
     WHERE member_id = :NEW.member_id;

    IF UPPER(NVL(v_role, '')) <> 'ADMIN' THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            '콘텐츠 작성자는 member_role=ADMIN(관리자) 계정만 가능합니다.'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            '작성자(member_id)가 회원 테이블에 존재하지 않습니다.'
        );
END;
/
-- ✅ 결과: 일반 사용자(user) 계정으로는 INSERT/UPDATE 불가

--------------------------------------------------------------------------------
-- 4) 트리거 #2: 수정일 자동 관리
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_contents_mod_ts';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_contents_mod_ts
BEFORE INSERT OR UPDATE ON contents_tbl
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.content_mod_date := NULL;                                -- 신규 생성 시 수정일은 NULL
    :NEW.content_reg_date := NVL(:NEW.content_reg_date, SYSDATE); -- 등록일 누락 시 기본값 보정
  ELSIF UPDATING THEN
    :NEW.content_mod_date := SYSDATE;                             -- 실제 수정 시각 자동 기록
  END IF;
END;
/
-- ✅ 결과: “수정하지 않았는데 수정일이 자동 입력” 문제 해소

--------------------------------------------------------------------------------
-- 5) 더미 데이터(재실행 대비 삭제 후 삽입)
--------------------------------------------------------------------------------
DELETE FROM contents_tbl WHERE content_id IN (1, 2);
COMMIT;

-- (1) 오시는 길
INSERT INTO contents_tbl (
    content_id, content_title, content_content, member_id, content_reg_date, content_use
) VALUES (
    1,
    '오시는 길',
    '<h2>오시는 길</h2><p>서울특별시 구로구 새말로9길 45</p>',
    'hong10',    -- 관리자
    SYSDATE,     -- 작성일
    'Y'          -- 사용
);

-- (2) 이용 안내
INSERT INTO contents_tbl (
    content_id, content_title, content_content, member_id, content_reg_date, content_use
) VALUES (
    2,
    '이용 안내',
    '<h2>이용 안내</h2><ul><li>운영시간 08:00~22:00</li><li>예약 필수</li></ul>',
    'hong8',     -- 관리자
    SYSDATE,
    'Y'
);

COMMIT;

--------------------------------------------------------------------------------
-- 6) 확인 조회(한글 별칭 + 날짜 포맷)
--------------------------------------------------------------------------------
SELECT
    content_id                               AS "콘텐츠번호",
    content_title                            AS "제목",
    member_id                                AS "작성자ID",
    CASE content_use WHEN 'Y' THEN '사용' ELSE '미사용' END AS "사용여부",
    TO_CHAR(content_reg_date, 'YYYY-MM-DD HH24:MI') AS "작성일",
    NVL(TO_CHAR(content_mod_date, 'YYYY-MM-DD HH24:MI'), '-') AS "수정일"  -- 수정 전이면 '-'
FROM contents_tbl
ORDER BY content_id;

--------------------------------------------------------------------------------
-- 7) (선택) 기존 잘못 채워진 수정일 정리
--------------------------------------------------------------------------------
-- UPDATE contents_tbl
--    SET content_mod_date = NULL
--  WHERE content_mod_date = content_reg_date;
-- COMMIT;

--------------------------------------------------------------------------------
-- 8-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(content_id 1,2 등)만 삭제 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM contents_tbl WHERE content_id IN (1, 2);
COMMIT;

--------------------------------------------------------------------------------
-- 8-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_contents_writer_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_contents_mod_ts';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE contents_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
