-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 재실행 안전 드롭
--------------------------------------------------------------------------------
/*
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE closed_day_tbl CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;   -- ORA-00942: 테이블 없음 → 무시
END;
/
*/

--------------------------------------------------------------------------------
-- 1) 휴무일설정 테이블 생성 (엑셀 사양 1:1)
--------------------------------------------------------------------------------
CREATE TABLE closed_day_tbl (
    closed_id       NUMBER        NOT NULL,       -- 휴무일 고유 번호 (PK)
    facility_id     NUMBER        NOT NULL,       -- 대상 시설 ID (FK → facility_tbl.facility_id)
    closed_date     DATE          NOT NULL,       -- 휴무일 날짜
    closed_content  VARCHAR2(200)                 -- 휴무 사유
);

-- 📌 주석
COMMENT ON TABLE  closed_day_tbl                    IS '휴무일 설정';
COMMENT ON COLUMN closed_day_tbl.closed_id          IS '휴무일 고유 번호';
COMMENT ON COLUMN closed_day_tbl.facility_id        IS '대상 시설 ID';
COMMENT ON COLUMN closed_day_tbl.closed_date        IS '휴무일 날짜';
COMMENT ON COLUMN closed_day_tbl.closed_content     IS '휴무 사유';

--------------------------------------------------------------------------------
-- 2) 제약조건/FK
--------------------------------------------------------------------------------
ALTER TABLE closed_day_tbl
  ADD CONSTRAINT closed_day_tbl_pk   PRIMARY KEY (closed_id);              -- PK

ALTER TABLE closed_day_tbl
  ADD CONSTRAINT closed_day_total_UN UNIQUE (facility_id, closed_date);    -- 동일 시설 중복 방지(복합 UNIQUE)

ALTER TABLE closed_day_tbl
  ADD CONSTRAINT fk_closed_facility
  FOREIGN KEY (facility_id) REFERENCES facility_tbl(facility_id);          -- FK 연결: facility_tbl

--------------------------------------------------------------------------------
-- 3) (권장) 조회 인덱스
--------------------------------------------------------------------------------
ALTER TABLE closed_day_tbl DROP CONSTRAINT closed_day_total_UN;

CREATE UNIQUE INDEX idx_closed_fac_date
ON closed_day_tbl (facility_id, closed_date);

--------------------------------------------------------------------------------
-- 4) 트리거 (선택) — 현재 규격에 없음 → 생략
--------------------------------------------------------------------------------
-- ※ 과거 날짜 입력 금지 같은 운영규칙이 필요하면 여기 추가

--------------------------------------------------------------------------------
-- 5) 더미데이터 (재실행 대비 정리 후 입력)
--------------------------------------------------------------------------------
DELETE FROM closed_day_tbl WHERE closed_id IN (1,2,3);
COMMIT;

INSERT INTO closed_day_tbl (closed_id, facility_id, closed_date, closed_content)
VALUES (1, 1, TRUNC(SYSDATE)+7,  '정기 점검');
INSERT INTO closed_day_tbl (closed_id, facility_id, closed_date, closed_content)
VALUES (2, 2, TRUNC(SYSDATE)+10, '시설 소독');
INSERT INTO closed_day_tbl (closed_id, facility_id, closed_date, closed_content)
VALUES (3, 1, TRUNC(SYSDATE)+14, '대관 행사');

COMMIT;

--------------------------------------------------------------------------------
-- 6) 확인 조회
--------------------------------------------------------------------------------
SELECT
    c.closed_id                         AS "휴무ID",
    c.facility_id                       AS "시설ID",
    f.facility_name                     AS "시설명",
    TO_CHAR(c.closed_date,'YYYY-MM-DD') AS "휴무일자",
    NVL(c.closed_content,'-')           AS "사유"
FROM closed_day_tbl c
JOIN facility_tbl   f ON f.facility_id = c.facility_id
ORDER BY c.facility_id, c.closed_date;

--------------------------------------------------------------------------------
-- 7) (선택) 부가 객체 — 없음
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 8-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(closed_id 1~3)만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM closed_day_tbl WHERE closed_id IN (1,2,3);
COMMIT;

--------------------------------------------------------------------------------
-- 8-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_closed_fac_date';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE closed_day_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
