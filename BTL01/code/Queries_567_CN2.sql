-- Câu 5: Tìm các sản phẩm có giá cao bán chạy tại Máy 2 và thuộc Danh mục quản lý ở Máy 1
SELECT
    -- 1. Thông tin định danh sản phẩm (Local - Máy 2)
    sp.MASANPHAM,
    sp.TENSANPHAM,
    sp.GIA AS Gia_Ban_Cuc_Bo,

    -- 2. Thông tin thuộc tính và danh mục (Xuyên Site - Máy 1)
    dm_m1.TENDANHMUC AS Nganh_Hang_Goc,
    tt_m1.TENTHUOCTINH,
    tt_m1.GIATRITHUOCTINH,

    -- 3. Thông tin kho vật lý và quản lý bán hàng tại Chi nhánh 2 (Local)
    k2.SOLUONG AS Ton_Kho_Vat_Ly_CN2,
    bh2.TINHTRANG AS Trang_Thai_Ban_CN2,
    bh2.TONGSLDABAN AS San_Luong_Ban_CN2,
    bh2.DIEMDANHGIA AS Diem_Review_CN2,

    -- 4. Thông tin kho vật lý và quản lý bán hàng tại Chi nhánh 1 (Xuyên Site - Máy 1)
    k1.SOLUONG AS Ton_Kho_Vat_Ly_CN1,
    bh1.TINHTRANG AS Trang_Thai_Ban_CN1,
    bh1.TONGSLDABAN AS San_Luong_Ban_CN1,
    bh1.TILETRAHANG AS Tile_Tra_Hang_CN1
FROM SANPHAM sp
         -- ==========================================
-- TẦNG 1: JOIN CÁC BẢNG CỤC BỘ TẠI MÁY 2 (LOCAL)
-- ==========================================
         JOIN KHOSANPHAM_QLKHO k2
              ON sp.MASANPHAM = k2.MASANPHAM
         JOIN KHOSANPHAM_QLBANHANG bh2
              ON sp.MASANPHAM = bh2.MASANPHAM AND k2.MACHINHANH = bh2.MACHINHANH

    -- ==========================================
-- TẦNG 2: JOIN XUYÊN SITE SANG MÁY 1 QUA LINK qlk2_qlk1
-- ==========================================
-- Khớp nối sang bảng Danh mục ở Máy 1
         JOIN CN1.DANHMUC_SANPHAM@qlk2_qlk1 dm_m1
              ON sp.MASANPHAM = dm_m1.MASANPHAM

-- Khớp nối sang bảng Thuộc tính sản phẩm chi tiết ở Máy 1
         JOIN CN1.THUOCTINH_SANPHAM@qlk2_qlk1 tt_m1
              ON sp.MASANPHAM = tt_m1.MASANPHAM

-- Khớp nối đối chiếu sang Kho vật lý của Chi nhánh 1 ở Máy 1
         JOIN CN1.KHOSANPHAM_QLKHO@qlk2_qlk1 k1
              ON sp.MASANPHAM = k1.MASANPHAM

-- Khớp nối đối chiếu sang Kho bán hàng của Chi nhánh 1 ở Máy 1
         JOIN CN1.KHOSANPHAM_QLBANHANG@qlk2_qlk1 bh1
              ON sp.MASANPHAM = bh1.MASANPHAM

-- ==========================================
-- TẦNG 3: BỘ LỌC ĐIỀU KIỆN
-- ==========================================
WHERE sp.GIA >= 500000                            -- Chỉ xét phân khúc sản phẩm từ trung cấp trở lên
  AND dm_m1.TENDANHMUC NOT IN (N'Phụ kiện rác')   -- Lọc bỏ các danh mục không quan trọng ở Máy 1
  AND k2.SOLUONG > 0                              -- Kho vật lý Máy 2 phải còn hàng
  AND k1.SOLUONG > 0                              -- Kho vật lý Máy 1 phải còn hàng
ORDER BY sp.GIA DESC, sp.MASANPHAM ASC;



--Câu 6: Đối chiếu lượng hàng tồn kho giữa Chi nhánh 2 và Chi nhánh 1 (Quản lý kho)
SELECT
    m2_kho.MASANPHAM,
    sp_m2.TENSANPHAM,
    sp_m2.GIA AS Gia_Ban,
    m2_kho.SOLUONG AS Ton_M2,
    (m2_kho.SOLUONG * sp_m2.GIA) AS GiaTri_Ton_M2,
    m1_kho.SOLUONG AS Ton_M1,
    (m1_kho.SOLUONG * sp_m2.GIA) AS GiaTri_Ton_M1
FROM KHOSANPHAM_QLKHO m2_kho
         JOIN SANPHAM sp_m2 ON m2_kho.MASANPHAM = sp_m2.MASANPHAM
-- [TRUY VẤN XUYÊN SITE MÁY 1]: Kết hợp với dữ liệu kho vật lý tại Máy 1 qua DBLink
         JOIN CN1.KHOSANPHAM_QLKHO@qlk2_qlk1 m1_kho ON m2_kho.MASANPHAM = m1_kho.MASANPHAM
WHERE m2_kho.SOLUONG > 50 AND m1_kho.SOLUONG > 50 -- Tiêu chí lọc sản phẩm ứ đọng hàng
ORDER BY GiaTri_Ton_M2 DESC;


--Câu 7: Thống kê doanh thu bán hàng của Khách hàng VIP trên cả 2 Chi nhánh (UNION ALL)
SELECT Báo_Cáo_Hàng_Hóa.*
FROM (
         SELECT
             Tong_SL.Noi_Kinh_Doanh,
             Tong_SL.MASANPHAM,
             sp_m2.TENSANPHAM,
             Tong_SL.Tong_So_Luong_Ban,
             Tong_SL.Ty_Le_Tra_Hang,
             -- Xếp hạng sản phẩm bán chạy nhất toàn hệ thống
             DENSE_RANK() OVER (PARTITION BY Tong_SL.Noi_Kinh_Doanh ORDER BY Tong_SL.Tong_So_Luong_Ban DESC) AS Xep_Hang_Ban_Chay
         FROM (
                  -- [NHÁNH 1]: Tính tổng số lượng đã bán dựa trên dữ liệu giao dịch thực tế tại Máy 2
                  SELECT
                      'Chi Nhánh 2' AS Noi_Kinh_Doanh,
                      ct2.MASANPHAM,
                      SUM(ct2.SOLUONG) AS Tong_So_Luong_Ban,
                      0.00 AS Ty_Le_Tra_Hang -- Máy 2 tính từ bảng đơn hàng thô
                  FROM CHITIETDONHANG ct2
                  GROUP BY ct2.MASANPHAM

                  UNION ALL

                  -- [NHÁNH 2]: Truy vấn xuyên Site lấy số liệu tổng hợp sẵn từ mảnh hỗn hợp tại Máy 1
                  SELECT
                      'Chi Nhánh 1' AS Noi_Kinh_Doanh,
                      m1_bh.MASANPHAM,
                      m1_bh.TONGSLDABAN AS Tong_So_Luong_Ban,
                      m1_bh.TILETRAHANG AS Ty_Le_Tra_Hang
                  FROM CN1.KHOSANPHAM_QLBANHANG@qlk2_qlk1 m1_bh
              ) Tong_SL
                  JOIN SANPHAM sp_m2 ON Tong_SL.MASANPHAM = sp_m2.MASANPHAM
     ) Báo_Cáo_Hàng_Hóa
WHERE Báo_Cáo_Hàng_Hóa.Xep_Hang_Ban_Chay <= 5;
