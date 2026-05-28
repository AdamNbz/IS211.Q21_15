----------------------------------------------------------------
-- UNOPTIMIZED QUERY
-- Bật thống kê thời gian thực trong Oracle
ALTER SESSION SET statistics_level = ALL;

SELECT /*+ GATHER_PLAN_STATISTICS MONITOR */ /* TIM_CAU_PHANG */
    sp.MASANPHAM,
    sp.TENSANPHAM,
    sp.GIA,
    hd.NGAYTAO,
    nv.HOTEN AS TenNhanVien
FROM CHITIETDONHANG ct
         JOIN DONHANG hd ON ct.MADONHANG = hd.MADONHANG
         JOIN NHANVIEN nv ON hd.MANHANVIEN = nv.MANHANVIEN
         JOIN CHINHANH cn ON nv.MACHINHANH = cn.MACHINHANH
         JOIN SANPHAM sp ON ct.MASANPHAM = sp.MASANPHAM
         JOIN DANHMUC_SANPHAM dm ON sp.MASANPHAM = dm.MASANPHAM
WHERE
    cn.MACHINHANH = 'CN02'
  AND sp.GIA >= 1000000
  AND dm.TENDANHMUC IN (N'Điện thoại', N'Máy tính xách tay')
  AND hd.NGAYTAO BETWEEN TO_DATE('2025-01-01', 'YYYY-MM-DD') AND TO_DATE('2025-12-31', 'YYYY-MM-DD');
-- Câu query trên tìm kiếm những sản phẩm có giá hơn 1 triệu đồng thuộc hai danh mục sản phẩm là điện thoại và
-- máy tính xách tay được bán ở chi nhánh 2 và được tạo trong năm 2025

SELECT sql_id, sql_text, last_load_time
FROM v$sql
WHERE sql_text LIKE '%TIM_CAU_PHANG%'
  AND sql_text NOT LIKE '%v$transaction%'
ORDER BY last_load_time DESC;
SELECT * FROM TABLE(dbms_xplan.display_cursor('5980wy80r68t6', NULL, 'ALLSTATS LAST'));

----------------------------------------------------------------------
-- OPTIMIZED QUERY using heuristics
ALTER SESSION SET statistics_level = ALL;

SELECT /*+ GATHER_PLAN_STATISTICS5 */
    "BLOCK3"."MASANPHAM",
    "BLOCK3"."TENSANPHAM",
    "BLOCK3"."GiaBan",
    "DM1"."TENDANHMUC",
    "BLOCK3"."NGAYTAO",
    "BLOCK3"."TenNhanVien"
FROM (
         SELECT
             "SP"."MASANPHAM",
             "SP"."TENSANPHAM",
             "SP"."GIA" AS "GiaBan",
             "BLOCK2"."TenNhanVien",
             "BLOCK2"."NGAYTAO"
         FROM (
                  SELECT
                      "CT1"."MASANPHAM",
                      "NV1"."TenNhanVien",
                      "HD1"."NGAYTAO"
                  FROM (
                           SELECT "NV"."MANHANVIEN", "NV"."HOTEN" AS "TenNhanVien"
                           FROM "NHANVIEN" "NV"
                           WHERE "NV"."MACHINHANH" = 'CN02'
                       ) "NV1"
                           JOIN (
                      SELECT "HD"."MADONHANG", "HD"."MANHANVIEN", "HD"."NGAYTAO"
                      FROM "DONHANG" "HD"
                      WHERE "HD"."NGAYTAO" BETWEEN TO_DATE('2025-01-01', 'YYYY-MM-DD') AND TO_DATE('2025-12-31', 'YYYY-MM-DD')
                  ) "HD1" ON "NV1"."MANHANVIEN" = "HD1"."MANHANVIEN"
                           JOIN (
                      SELECT "MADONHANG", "MASANPHAM"
                      FROM "CHITIETDONHANG"
                  ) "CT1" ON "CT1"."MADONHANG" = "HD1"."MADONHANG"
              ) "BLOCK2"
                  JOIN (
             SELECT "SP_GOC"."MASANPHAM", "SP_GOC"."TENSANPHAM", "SP_GOC"."GIA"
             FROM "SANPHAM" "SP_GOC"
             WHERE "SP_GOC"."GIA" >= 1000000
         ) "SP" ON "SP"."MASANPHAM" = "BLOCK2"."MASANPHAM"
     ) "BLOCK3"
         JOIN (
    SELECT "MASANPHAM", "TENDANHMUC"
    FROM "DANHMUC_SANPHAM"
    WHERE "TENDANHMUC" IN (N'Điện thoại', N'Máy tính xách tay')
) "DM1" ON "BLOCK3"."MASANPHAM" = "DM1"."MASANPHAM";

-- Tìm SQL_ID của câu truy vấn tối ưu vừa thực thi
SELECT sql_id, child_number, plan_hash_value, last_active_time, sql_text
FROM v$sql
WHERE UPPER(sql_text) LIKE '%GATHER_PLAN_STATISTICS5%'
  AND UPPER(sql_text) NOT LIKE '%V$SQL%'  -- BẮT BUỘC: Loại trừ chính câu lệnh tìm kiếm này
  AND UPPER(sql_text) LIKE '%BLOCK3%'     -- Chắc chắn phải chứa từ khóa của câu query gốc
ORDER BY last_active_time DESC;

SELECT * FROM TABLE(dbms_xplan.display_cursor('9szuftjj9bvz7', NULL, 'ALLSTATS LAST'));

SELECT * FROM TABLE(dbms_xplan.display_cursor('a5vgk25st67wq', NULL, 'ALLSTATS LAST'));


----------------------------------------------------
-- INDEX
----------------------------------------------------
CREATE BITMAP INDEX idx_nhanvien_macn_bmp ON NHANVIEN(MACHINHANH);
CREATE INDEX idx_danhmuc_ten_ma ON DANHMUC_SANPHAM(TENDANHMUC, MASANPHAM);
CREATE INDEX idx_sp_giaban_2026 ON SANPHAM(GIA);