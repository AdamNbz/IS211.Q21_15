-- Thực thi tại Site 3 với quyền QuanLyKho
WITH ALL_KHO AS (
    -- Site 3: Miền Trung - dữ liệu local
    SELECT
        MASANPHAM,
        MACHINHANH,
        SOLUONG,
        N'Miền Trung' AS VUNG_MIEN
    FROM CN3.KHOSANPHAM_QLKHO

    UNION ALL

    -- Site 1: Miền Nam - dữ liệu qua DB Link từ Site 3 sang Site 1
    SELECT
        MASANPHAM,
        MACHINHANH,
        SOLUONG,
        N'Miền Nam' AS VUNG_MIEN
    FROM CN1.KHOSANPHAM_QLKHO@qlk3_to_qlk1

    UNION ALL

    -- Site 2: Miền Bắc - dữ liệu qua DB Link từ Site 3 sang Site 2
    SELECT
        MASANPHAM,
        MACHINHANH,
        SOLUONG,
        N'Miền Bắc' AS VUNG_MIEN
    FROM CN2.KHOSANPHAM_QLKHO@qlk3_to_qlk2
),

KHO_WITH_TOTAL AS (
    -- Tính tổng tồn kho toàn hệ thống của từng sản phẩm
    SELECT
        MASANPHAM,
        MACHINHANH,
        VUNG_MIEN,
        SOLUONG,
        SUM(SOLUONG) OVER (PARTITION BY MASANPHAM) AS TONG_TON_TOAN_HE_THONG
    FROM ALL_KHO
)

SELECT
    kwt.VUNG_MIEN,
    kwt.MACHINHANH,
    kwt.MASANPHAM,
    sp.TENSANPHAM,
    kwt.SOLUONG AS TON_KHO_TAI_CHI_NHANH,
    kwt.TONG_TON_TOAN_HE_THONG,
    ROUND(
        kwt.SOLUONG * 100 / NULLIF(kwt.TONG_TON_TOAN_HE_THONG, 0),
        2
    ) AS TY_LE_TON_KHO_PHAN_TRAM
FROM KHO_WITH_TOTAL kwt
JOIN CN3.SANPHAM sp
    ON kwt.MASANPHAM = sp.MASANPHAM
WHERE kwt.SOLUONG / NULLIF(kwt.TONG_TON_TOAN_HE_THONG, 0) >= 0.5
ORDER BY TY_LE_TON_KHO_PHAN_TRAM DESC, kwt.MASANPHAM;