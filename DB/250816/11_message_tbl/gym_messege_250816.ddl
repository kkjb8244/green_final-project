-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 재실행 안전 드롭  ----------------------------------------------  [추가]
--    - 테이블/시퀀스가 이미 있더라도 에러 없이 재실행 가능하게 처리
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE message_tbl CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;   -- ORA-00942: 테이블 없음 → 무시
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_message_id';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF;  -- ORA-02289: 시퀀스 없음 → 무시
END;
/

--------------------------------------------------------------------------------
-- 1) 문자전송(message_tbl) 테이블 생성  
--------------------------------------------------------------------------------
CREATE TABLE message_tbl (
    message_id      NUMBER          NOT NULL,                 -- 문자 이력 고유 ID (PK)
    member_id       VARCHAR2(20)    NOT NULL,                 -- 문자 수신자 ID (FK → member_tbl.member_id)
    resv_id         NUMBER,                                   -- 관련 예약 ID (nullable, FK → reservation_tbl.resv_id)
    closed_id       NUMBER,                                   -- 관련 휴관일 ID (nullable, FK → closed_day_tbl.closed_id)
    message_type    VARCHAR2(20)    NOT NULL,                 -- 문자 분류 유형
    message_content CLOB,                                     -- 실제 발송된 문자 내용
    message_date    DATE            DEFAULT SYSDATE NOT NULL  -- 문자 발송 일시(기본값 SYSDATE)
);

--------------------------------------------------------------------------------
-- 2) 테이블/컬럼 주석  
--------------------------------------------------------------------------------
COMMENT ON TABLE  message_tbl                  IS '문자전송 이력';
COMMENT ON COLUMN message_tbl.message_id       IS '문자 이력 고유 ID (PK)';
COMMENT ON COLUMN message_tbl.member_id        IS '문자 수신자 ID (FK)';
COMMENT ON COLUMN message_tbl.resv_id          IS '관련 예약 ID (nullable, FK)';
COMMENT ON COLUMN message_tbl.closed_id        IS '관련 휴관일 ID (nullable, FK)';
COMMENT ON COLUMN message_tbl.message_type     IS '문자 분류 유형';
COMMENT ON COLUMN message_tbl.message_content  IS '실제 발송된 문자 내용';
COMMENT ON COLUMN message_tbl.message_date     IS '문자 발송 일시';

--------------------------------------------------------------------------------
-- 3) 제약조건  
--------------------------------------------------------------------------------
-- (PK) 기본키
ALTER TABLE message_tbl
  ADD CONSTRAINT message_tbl_pk PRIMARY KEY (message_id);

-- (CHECK) 문자유형 제한
ALTER TABLE message_tbl
  ADD CONSTRAINT message_type_CH
  CHECK (message_type IN ('예약확인', '예약취소', '휴관공지'));

-- (UNIQUE) 같은 시간에 같은 유형 문자 중복 방지
ALTER TABLE message_tbl
  ADD CONSTRAINT message_total_UN
  UNIQUE (member_id, message_type, message_date);

-- (FK) 회원
ALTER TABLE message_tbl
  ADD CONSTRAINT fk_msg_mem
  FOREIGN KEY (member_id) REFERENCES member_tbl(member_id);

-- (FK) 예약 (nullable)
ALTER TABLE message_tbl
  ADD CONSTRAINT fk_msg_resv
  FOREIGN KEY (resv_id) REFERENCES reservation_tbl(resv_id);

-- (FK) 휴무/휴관 (nullable)
ALTER TABLE message_tbl
  ADD CONSTRAINT fk_msg_closed
  FOREIGN KEY (closed_id) REFERENCES closed_day_tbl(closed_id);

--------------------------------------------------------------------------------
-- 4) 시퀀스(자동 번호 증가) [추가]
--------------------------------------------------------------------------------
CREATE SEQUENCE seq_message_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

--------------------------------------------------------------------------------
-- 5) 더미 데이터 [추가]
--    ⚠ FK 유효성 때문에, 실제 존재하는 값으로 넣어야 함.
--    - member_id는 기존에 생성된 계정 예: 'hong10' 사용 권장
--    - resv_id, closed_id는 존재 확인되기 전에는 NULL로 두는 예시 제공
--------------------------------------------------------------------------------
-- (예시) 예약확인 문자 (resv_id는 아직 모르면 NULL)
INSERT INTO message_tbl (
  message_id, member_id, resv_id, closed_id, message_type, message_content
) VALUES (
  seq_message_id.NEXTVAL, 'hong10', NULL, NULL, '예약확인',
  'hong10님, 예약이 확정되었습니다.'
);

-- (예시) 휴관 공지 문자 (closed_id는 아직 모르면 NULL)
INSERT INTO message_tbl (
  message_id, member_id, resv_id, closed_id, message_type, message_content
) VALUES (
  seq_message_id.NEXTVAL, 'hong10', NULL, NULL, '휴관공지',
  '금일 일부 시설이 휴관입니다.'
);

COMMIT;

--------------------------------------------------------------------------------
-- 6) 확인 조회(워크시트)
--------------------------------------------------------------------------------
SELECT
    m.message_id    AS "메시지ID (PK)",
    m.member_id     AS "수신자ID (FK)",
    m.resv_id       AS "예약ID (FK/nullable)",
    m.closed_id     AS "휴관ID (FK/nullable)",
    m.message_type  AS "문자유형",
    SUBSTR(m.message_content, 1, 100) AS "문자내용(100자)",
    TO_CHAR(m.message_date, 'YYYY-MM-DD HH24:MI:SS') AS "발송일시"
FROM message_tbl m
ORDER BY m.message_id;

--------------------------------------------------------------------------------
-- 7-1) 💀 데이터 초기화 (안전 모드)  ---------------------------------  [추가]
--      - 데이터만 삭제 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM message_tbl;
COMMIT;

-- 시퀀스 재시작(선택): 기존 시퀀스 있으면 삭제 후 1부터 재생성
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_message_id';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF;  -- ORA-02289: 시퀀스 없음 → 무시
END;
/
CREATE SEQUENCE seq_message_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

--------------------------------------------------------------------------------
-- 7-2) 💀 ddl 블록까지 안전 삭제  ------------------------------------  [추가]
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TABLE message_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_message_id';                 EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
