-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;


--------------------------------------------------------------------------------
-- 1) 결제신청+내역 (payment_tbl)
--------------------------------------------------------------------------------
CREATE TABLE payment_tbl (
    payment_id      NUMBER        NOT NULL,                    -- PK
    member_id       VARCHAR2(20)  NOT NULL,                    -- FK → member_tbl
    account_id      NUMBER        NOT NULL,                    -- FK → account_tbl
    card_id         NUMBER        NOT NULL,                    -- FK → card_tbl
    resv_id         NUMBER        NOT NULL,                    -- FK → reservation_tbl
    payment_money   NUMBER        NOT NULL,
    payment_method  VARCHAR2(20)  DEFAULT '계좌' NOT NULL,     -- 카드/계좌/현금
    payment_status  VARCHAR2(20)  DEFAULT '예약중' NOT NULL,   -- 완료/예약중/취소/실패
    payment_date    DATE          DEFAULT SYSDATE
);

ALTER TABLE payment_tbl ADD CONSTRAINT payment_tbl_pk PRIMARY KEY (payment_id);

ALTER TABLE payment_tbl
  ADD CONSTRAINT payment_method_CH CHECK (payment_method IN ('카드','계좌','현금'));

ALTER TABLE payment_tbl
  ADD CONSTRAINT payment_status_CH CHECK (payment_status IN ('완료','예약중','취소','실패'));

-- FK (존재할 경우에만 추가)
ALTER TABLE payment_tbl
  ADD CONSTRAINT fk_payment_member FOREIGN KEY (member_id) REFERENCES member_tbl(member_id);
ALTER TABLE payment_tbl
  ADD CONSTRAINT fk_payment_account FOREIGN KEY (account_id) REFERENCES account_tbl(account_id);
ALTER TABLE payment_tbl
  ADD CONSTRAINT fk_payment_card FOREIGN KEY (card_id) REFERENCES card_tbl(card_id);
ALTER TABLE payment_tbl
  ADD CONSTRAINT fk_payment_reservation FOREIGN KEY (resv_id) REFERENCES reservation_tbl(resv_id);

-- 인덱스
CREATE INDEX idx_payment_member  ON payment_tbl(member_id);
CREATE INDEX idx_payment_resv    ON payment_tbl(resv_id);
CREATE INDEX idx_payment_date    ON payment_tbl(payment_date);

-- 시퀀스 & 트리거
CREATE SEQUENCE seq_payment_id START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_payment_id
BEFORE INSERT ON payment_tbl
FOR EACH ROW
BEGIN
  IF :NEW.payment_id IS NULL THEN
    :NEW.payment_id := seq_payment_id.NEXTVAL;
  END IF;
END;
/

--------------------------------------------------------------------------------
-- 2) 결제로그 (paylog_tbl)
--------------------------------------------------------------------------------
CREATE TABLE paylog_tbl (
    paylog_id            NUMBER        NOT NULL,                 -- PK
    payment_id           NUMBER        NOT NULL,                 -- FK → payment_tbl
    paylog_type          VARCHAR2(20)  NOT NULL,                 -- 결제/취소/환불/실패/수정/삭제
    paylog_before_status VARCHAR2(20),                           -- 변경 전 상태
    paylog_after_status  VARCHAR2(20),                           -- 변경 후 상태
    paylog_money         NUMBER,
    paylog_method        VARCHAR2(20),
    paylog_manager       VARCHAR2(20),
    paylog_memo          VARCHAR2(200),
    paylog_date          DATE DEFAULT SYSDATE
);

ALTER TABLE paylog_tbl ADD CONSTRAINT paylog_tbl_pk PRIMARY KEY (paylog_id);

ALTER TABLE paylog_tbl
  ADD CONSTRAINT fk_paylog_payment FOREIGN KEY (payment_id)
  REFERENCES payment_tbl(payment_id) ON DELETE CASCADE;

ALTER TABLE paylog_tbl
  ADD CONSTRAINT paylog_type_CH CHECK (paylog_type IN ('결제','취소','환불','실패','수정','삭제'));

-- 시퀀스 & 트리거
CREATE SEQUENCE seq_paylog_id START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_paylog_id
BEFORE INSERT ON paylog_tbl
FOR EACH ROW
BEGIN
  IF :NEW.paylog_id IS NULL THEN
    :NEW.paylog_id := seq_paylog_id.NEXTVAL;
  END IF;
END;
/

--------------------------------------------------------------------------------
-- 3) 트리거: payment_tbl 변경 시 자동 로그 기록
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_payment_to_paylog
AFTER INSERT OR UPDATE OR DELETE ON payment_tbl
FOR EACH ROW
DECLARE
  v_type VARCHAR2(20);
BEGIN
  IF INSERTING THEN
    v_type := '결제';
    INSERT INTO paylog_tbl(payment_id, paylog_type, paylog_after_status, paylog_money, paylog_method, paylog_date)
    VALUES (:NEW.payment_id, v_type, :NEW.payment_status, :NEW.payment_money, :NEW.payment_method, SYSDATE);

  ELSIF UPDATING THEN
    v_type := '수정';
    INSERT INTO paylog_tbl(payment_id, paylog_type, paylog_before_status, paylog_after_status, paylog_money, paylog_method, paylog_date)
    VALUES (:OLD.payment_id, v_type, :OLD.payment_status, :NEW.payment_status, :NEW.payment_money, :NEW.payment_method, SYSDATE);

  ELSIF DELETING THEN
    v_type := '삭제';
    INSERT INTO paylog_tbl(payment_id, paylog_type, paylog_before_status, paylog_money, paylog_method, paylog_date)
    VALUES (:OLD.payment_id, v_type, :OLD.payment_status, :OLD.payment_money, :OLD.payment_method, SYSDATE);
  END IF;
END;
/

--------------------------------------------------------------------------------
-- 4) 테스트용 더미데이터
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 4-1) ★★★★ 테스트용 더미데이터하기 전에 ID 존재 유무 체크 ★★★★

-- 아이디 존재 여부 체크
SELECT * FROM member_tbl WHERE member_id='hong4'; -- hong4라는 계정이 있나?

-- 계좌 테이블에 id값 존재 여부 체크
SELECT * FROM account_tbl WHERE account_id=1; -- 계좌ID 1이라는 아이디 있나?

-- 카드 테이블에 id 값 존재 여부 체크
SELECT * FROM card_tbl WHERE card_id=1; -- 카드ID에 1이라는 아이디 있나?

-- 신청 내역 중에서 해당 id값 존재 여부 체크
SELECT * FROM reservation_tbl WHERE resv_id=1; -- 신청(예약)ID 중에서 1이라는 아이디 있나?

--------------------------------------------------------------------------------
-- 4-2) 테스트용 더미데이터 생성하기

INSERT INTO payment_tbl(member_id, account_id, card_id, resv_id, payment_money, payment_method, payment_status)
VALUES('hong1', 1, 1, 1, 50000, '계좌', '예약중');

INSERT INTO payment_tbl(member_id, account_id, card_id, resv_id, payment_money, payment_method, payment_status)
VALUES('hong2', 1, 1, 2, 80000, '카드', '완료');

INSERT INTO payment_tbl(member_id, account_id, card_id, resv_id, payment_money, payment_method, payment_status)
VALUES('hong3', 1, 1, 3, 80000, '카드', '완료');

INSERT INTO payment_tbl(member_id, account_id, card_id, resv_id, payment_money, payment_method, payment_status)
VALUES('hong4', 1, 1, 2, 80000, '카드', '취소');

COMMIT;

--------------------------------------------------------------------------------
-- 5) 정보 조회 
--------------------------------------------------------------------------------
-- 결제 신청 내역
SELECT
    p.payment_id     AS "결제ID",
    p.member_id      AS "회원ID",
    p.account_id     AS "계좌ID",
    p.card_id        AS "카드ID",
    p.resv_id        AS "예약ID",
    p.payment_money  AS "결제금액",
    p.payment_method AS "결제방식",
    CASE p.payment_status
        WHEN '완료'   THEN '완료'
        WHEN '예약중' THEN '예약중'
        WHEN '취소'   THEN '취소'
        WHEN '실패'   THEN '실패'
        ELSE p.payment_status
    END              AS "결제상태",
    TO_CHAR(p.payment_date, 'YYYY-MM-DD HH24:MI') AS "결제일시"
FROM payment_tbl p
ORDER BY p.payment_id;

-- 결제 로그
SELECT
    l.paylog_id          AS "로그ID",
    l.payment_id         AS "결제ID",
    l.paylog_type        AS "로그유형",    -- (결제, 수정, 취소, 삭제 등)
    l.paylog_before_status AS "이전상태",
    l.paylog_after_status  AS "이후상태",
    l.paylog_money       AS "금액",
    l.paylog_method      AS "방식",
    l.paylog_manager     AS "담당자",
    l.paylog_memo        AS "메모",
    TO_CHAR(l.paylog_date, 'YYYY-MM-DD HH24:MI') AS "로그일시"
FROM paylog_tbl l
ORDER BY l.paylog_id;




--------------------------------------------------------------------------------
-- 6-1) 💀 데이터 초기화 (자식 → 부모 순서) 💀
-- ※ 테이블 구조는 유지 / 데이터와 시퀀스만 초기화
--------------------------------------------------------------------------------

-- 0) 로깅 트리거 일시 비활성화 (없으면 무시)

BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_payment_to_paylog DISABLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_paylog_aiu DISABLE';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_paylog_ad DISABLE';         EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 1) 자식 → 부모 순서로 데이터 삭제

DELETE FROM paylog_tbl;   -- 자식 먼저
COMMIT;

DELETE FROM payment_tbl;  -- 부모 다음
COMMIT;

-- 2) 시퀀스 번호 초기화 (동일 이름으로 재생성)

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_paylog_id';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE seq_paylog_id  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_payment_id'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE seq_payment_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/


-- 3) 로깅 트리거 재활성화 (없으면 무시)
BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_payment_to_paylog ENABLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_paylog_aiu ENABLE';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_paylog_ad ENABLE';         EXCEPTION WHEN OTHERS THEN NULL; END;
/

--------------------------------------------------------------------------------
-- 6-2) 💀 ddl 블록까지 안전 삭제 (자식 → 부모 순서) 💀 
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_payment_id'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_paylog_id';  EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP TABLE paylog_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE payment_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_payment_id'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_paylog_id';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/