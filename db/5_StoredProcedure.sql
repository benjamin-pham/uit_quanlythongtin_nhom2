/* =====================================================================
   File   : 05_StoredProcedure.sql
   Noi dung: STORED PROCEDURE
     A. Tham so vao          : SP_THEMDOCGIA, SP_TIMSACH
     B. Tham so vao va ra    : SP_LAPPHIEUMUON, SP_TRASACH,
                               SP_THANHTOANPHAT, SP_THONGKETHANG
   ===================================================================== */

USE QUANLYTHUVIEN
GO

/* ---------------------------------------------------------------------
   SP 1. Them doc gia moi.
   Tham so vao: MADG, HOTEN, NGSINH, GIOITINH, DIACHI, SODT, EMAIL, MALDG.
   - MADG da ton tai          -> tra ve 0
   - MALDG khong ton tai      -> tra ve 1
   - Nguoc lai insert, ngay lap the = hom nay, han the: khach ngoai 6 thang,
     cac loai khac 2 nam      -> tra ve 2
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_THEMDOCGIA
	@MADG		CHAR(5),
	@HOTEN		NVARCHAR(40),
	@NGSINH		DATE,
	@GIOITINH	NVARCHAR(3),
	@DIACHI		NVARCHAR(100),
	@SODT		VARCHAR(15),
	@EMAIL		VARCHAR(50),
	@MALDG		CHAR(2)
AS
BEGIN
	IF EXISTS (SELECT * FROM DOCGIA WHERE MADG = @MADG)
	BEGIN
		PRINT N'Mã độc giả đã tồn tại.'
		RETURN 0
	END

	IF NOT EXISTS (SELECT * FROM LOAIDOCGIA WHERE MALDG = @MALDG)
	BEGIN
		PRINT N'Loại độc giả không tồn tại.'
		RETURN 1
	END

	DECLARE @NGAYLAP DATE = GETDATE()
	DECLARE @HETHAN DATE = CASE WHEN @MALDG = 'KH' THEN DATEADD(MONTH, 6, @NGAYLAP)
								ELSE DATEADD(YEAR, 2, @NGAYLAP) END

	INSERT INTO DOCGIA (MADG, HOTEN, NGSINH, GIOITINH, DIACHI, SODT, EMAIL, MALDG, NGAYLAPTHE, NGAYHETHAN)
	VALUES (@MADG, @HOTEN, @NGSINH, @GIOITINH, @DIACHI, @SODT, @EMAIL, @MALDG, @NGAYLAP, @HETHAN)

	PRINT N'Thêm độc giả thành công.'
	RETURN 2
END
GO

/* ---------------------------------------------------------------------
   SP 2. Tim sach theo tu khoa (ten sach, ten tac gia hoac ten the loai).
   Tham so vao: TUKHOA. Tra ve danh sach dau sach va so cuon con san.
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_TIMSACH
	@TUKHOA NVARCHAR(100)
AS
BEGIN
	SELECT	DS.MADS, DS.TENDS, TL.TENTL, NXB.TENNXB, DS.NAMXB,
			STUFF((SELECT N', ' + TG.TENTG
				   FROM DAUSACH_TACGIA DT JOIN TACGIA TG ON DT.MATG = TG.MATG
				   WHERE DT.MADS = DS.MADS
				   FOR XML PATH('')), 1, 2, '') AS TACGIA,
			DS.SOLUONG, DS.SLCON
	FROM DAUSACH DS
		JOIN THELOAI TL ON DS.MATL = TL.MATL
		JOIN NHAXUATBAN NXB ON DS.MANXB = NXB.MANXB
	WHERE DS.TENDS LIKE N'%' + @TUKHOA + N'%'
	   OR TL.TENTL LIKE N'%' + @TUKHOA + N'%'
	   OR EXISTS (SELECT * FROM DAUSACH_TACGIA DT JOIN TACGIA TG ON DT.MATG = TG.MATG
				  WHERE DT.MADS = DS.MADS AND TG.TENTG LIKE N'%' + @TUKHOA + N'%')
	ORDER BY DS.TENDS
END
GO

/* ---------------------------------------------------------------------
   SP 3. Lap phieu muon.
   Tham so vao : MADG, MANV, danh sach ma cuon sach cach nhau boi dau phay
                 (VD: 'CS001,CS010').
   Tham so ra  : MAPM vua tao.
   - Ma phieu tu tang, han tra = ngay muon + so ngay muon cua loai doc gia.
   - Cac rang buoc (the con han, khong no, so sach toi da, sach co san)
     do TRG_PHIEUMUON_KIEMTRA va TRG_CTPM_MUONSACH kiem tra.
   - Tat ca trong 1 transaction: loi o bat ky cuon nao thi huy toan bo.
   Tra ve: 1 thanh cong, 0 that bai.
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_LAPPHIEUMUON
	@MADG	CHAR(5),
	@MANV	CHAR(4),
	@DSMACS	VARCHAR(200),
	@MAPM	CHAR(6) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @MAPM = NULL

	IF NOT EXISTS (SELECT * FROM DOCGIA WHERE MADG = @MADG)
	BEGIN
		PRINT N'Độc giả không tồn tại.'
		RETURN 0
	END

	IF NOT EXISTS (SELECT * FROM STRING_SPLIT(@DSMACS, ',') WHERE LTRIM(RTRIM(value)) <> '')
	BEGIN
		PRINT N'Phiếu mượn phải có ít nhất một cuốn sách.'
		RETURN 0
	END

	DECLARE @SONGAY INT
	SELECT @SONGAY = LDG.SONGAYMUON
	FROM DOCGIA DG JOIN LOAIDOCGIA LDG ON DG.MALDG = LDG.MALDG
	WHERE DG.MADG = @MADG

	BEGIN TRY
		BEGIN TRANSACTION

		DECLARE @MAX INT
		SELECT @MAX = ISNULL(MAX(CAST(SUBSTRING(MAPM, 3, 4) AS INT)), 0)
		FROM PHIEUMUON WITH (UPDLOCK, HOLDLOCK)

		SET @MAPM = 'PM' + RIGHT('0000' + CAST(@MAX + 1 AS VARCHAR(4)), 4)

		INSERT INTO PHIEUMUON (MAPM, MADG, MANV, NGAYMUON, HANTRA, TINHTRANG)
		VALUES (@MAPM, @MADG, @MANV, CAST(GETDATE() AS DATE),
				DATEADD(DAY, @SONGAY, CAST(GETDATE() AS DATE)), N'Đang mượn')

		INSERT INTO CTPHIEUMUON (MAPM, MACS)
		SELECT DISTINCT @MAPM, LTRIM(RTRIM(value))
		FROM STRING_SPLIT(@DSMACS, ',')
		WHERE LTRIM(RTRIM(value)) <> ''

		COMMIT TRANSACTION
		PRINT N'Lập phiếu mượn ' + @MAPM + N' thành công.'
		RETURN 1
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION
		SET @MAPM = NULL
		DECLARE @LOI NVARCHAR(4000) = ERROR_MESSAGE()
		RAISERROR (@LOI, 16, 1)
		RETURN 0
	END CATCH
END
GO

/* ---------------------------------------------------------------------
   SP 4. Tra sach.
   Tham so vao : MAPM, MACS, tinh trang khi tra (mac dinh 'Bình thường').
   Tham so ra  : TIENPHAT - tong tien phat phat sinh cho lan tra nay.
   - Khong tim thay chi tiet phieu muon -> tra ve 0
   - Sach da tra truoc do             -> tra ve 1
   - Nguoc lai cap nhat ngay tra = hom nay (trigger TRG_CTPM_TRASACH tu
     cap nhat tinh trang sach, lap phieu phat)  -> tra ve 2
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_TRASACH
	@MAPM			CHAR(6),
	@MACS			CHAR(5),
	@TINHTRANGTRA	NVARCHAR(20) = N'Bình thường',
	@TIENPHAT		MONEY OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @TIENPHAT = 0

	IF NOT EXISTS (SELECT * FROM CTPHIEUMUON WHERE MAPM = @MAPM AND MACS = @MACS)
	BEGIN
		PRINT N'Không tìm thấy sách trong phiếu mượn.'
		RETURN 0
	END

	IF EXISTS (SELECT * FROM CTPHIEUMUON WHERE MAPM = @MAPM AND MACS = @MACS AND NGAYTRA IS NOT NULL)
	BEGIN
		PRINT N'Sách này đã được trả trước đó.'
		RETURN 1
	END

	UPDATE CTPHIEUMUON
	SET NGAYTRA = CAST(GETDATE() AS DATE), TINHTRANGTRA = @TINHTRANGTRA
	WHERE MAPM = @MAPM AND MACS = @MACS

	SELECT @TIENPHAT = ISNULL(SUM(SOTIEN), 0)
	FROM PHIEUPHAT
	WHERE MAPM = @MAPM AND MACS = @MACS AND DATHANHTOAN = 0

	PRINT N'Trả sách thành công. Tiền phạt: ' + FORMAT(@TIENPHAT, 'N0') + N' đ'
	RETURN 2
END
GO

/* ---------------------------------------------------------------------
   SP 5. Thanh toan toan bo tien phat cua doc gia.
   Tham so vao : MADG.   Tham so ra: SOTIEN da thanh toan.
   - Doc gia khong ton tai -> tra ve 0
   - Doc gia khong co no   -> tra ve 1
   - Nguoc lai danh dau cac phieu phat da thanh toan
     (TRG_PHIEUPHAT_TONGNO cap nhat lai TONGNO) -> tra ve 2
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_THANHTOANPHAT
	@MADG	CHAR(5),
	@SOTIEN	MONEY OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @SOTIEN = 0

	IF NOT EXISTS (SELECT * FROM DOCGIA WHERE MADG = @MADG)
	BEGIN
		PRINT N'Độc giả không tồn tại.'
		RETURN 0
	END

	SELECT @SOTIEN = ISNULL(SUM(PP.SOTIEN), 0)
	FROM PHIEUPHAT PP JOIN PHIEUMUON PM ON PP.MAPM = PM.MAPM
	WHERE PM.MADG = @MADG AND PP.DATHANHTOAN = 0

	IF @SOTIEN = 0
	BEGIN
		PRINT N'Độc giả không có khoản phạt nào chưa thanh toán.'
		RETURN 1
	END

	UPDATE PHIEUPHAT
	SET DATHANHTOAN = 1
	WHERE DATHANHTOAN = 0
	  AND MAPM IN (SELECT MAPM FROM PHIEUMUON WHERE MADG = @MADG)

	PRINT N'Đã thanh toán ' + FORMAT(@SOTIEN, 'N0') + N' đ.'
	RETURN 2
END
GO

/* ---------------------------------------------------------------------
   SP 6. Thong ke hoat dong thu vien theo thang.
   Tham so vao : THANG, NAM.
   Tham so ra  : so phieu muon, so luot sach duoc muon, tong tien phat
                 phat sinh trong thang.
   Dong thoi tra ve bang top 5 dau sach duoc muon nhieu nhat trong thang.
   --------------------------------------------------------------------- */
CREATE PROCEDURE SP_THONGKETHANG
	@THANG		INT,
	@NAM		INT,
	@SOPHIEU	INT OUTPUT,
	@SOLUOTSACH	INT OUTPUT,
	@TIENPHAT	MONEY OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	SELECT @SOPHIEU = COUNT(*)
	FROM PHIEUMUON
	WHERE MONTH(NGAYMUON) = @THANG AND YEAR(NGAYMUON) = @NAM

	SELECT @SOLUOTSACH = COUNT(*)
	FROM CTPHIEUMUON CT JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
	WHERE MONTH(PM.NGAYMUON) = @THANG AND YEAR(PM.NGAYMUON) = @NAM

	SELECT @TIENPHAT = ISNULL(SUM(SOTIEN), 0)
	FROM PHIEUPHAT
	WHERE MONTH(NGAYLAP) = @THANG AND YEAR(NGAYLAP) = @NAM

	SELECT TOP 5 DS.MADS, DS.TENDS, COUNT(*) AS SOLUOTMUON
	FROM CTPHIEUMUON CT
		JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
		JOIN CUONSACH CS ON CT.MACS = CS.MACS
		JOIN DAUSACH DS ON CS.MADS = DS.MADS
	WHERE MONTH(PM.NGAYMUON) = @THANG AND YEAR(PM.NGAYMUON) = @NAM
	GROUP BY DS.MADS, DS.TENDS
	ORDER BY SOLUOTMUON DESC, DS.MADS
END
GO

/* ---------------------- VI DU SU DUNG ------------------------------
DECLARE @KQ INT
EXEC @KQ = SP_THEMDOCGIA 'DG016', N'Trương Thị Hoa', '2005-05-05', N'Nữ', N'Thủ Đức, TpHCM', '0901234576', NULL, 'SV'
SELECT @KQ AS KETQUA

EXEC SP_TIMSACH N'Nguyễn Nhật Ánh'

DECLARE @MAPM CHAR(6), @KQ2 INT
EXEC @KQ2 = SP_LAPPHIEUMUON 'DG012', 'NV02', 'CS001,CS010', @MAPM OUTPUT
SELECT @KQ2 AS KETQUA, @MAPM AS MAPM

DECLARE @PHAT MONEY
EXEC SP_TRASACH 'PM0012', 'CS025', N'Bình thường', @PHAT OUTPUT
SELECT @PHAT AS TIENPHAT

DECLARE @TIEN MONEY
EXEC SP_THANHTOANPHAT 'DG009', @TIEN OUTPUT
SELECT @TIEN AS DATHANHTOAN

DECLARE @SP INT, @SL INT, @TP MONEY
EXEC SP_THONGKETHANG 7, 2026, @SP OUTPUT, @SL OUTPUT, @TP OUTPUT
SELECT @SP AS SOPHIEU, @SL AS SOLUOTSACH, @TP AS TIENPHAT
--------------------------------------------------------------------- */
