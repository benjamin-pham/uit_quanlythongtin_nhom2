/* =====================================================================
   File   : 03_Function.sql
   Noi dung: 3 FUNCTION (2 ham tra ve gia tri vo huong, 1 ham tra ve bang)
   ===================================================================== */

USE QUANLYTHUVIEN
GO

/* ---------------------------------------------------------------------
   FUNCTION 1. Dua vao MADG, tra ve so cuon sach doc gia do dang muon
   (chua tra). Neu khong tim thay doc gia thi tra ve -1.
   --------------------------------------------------------------------- */
CREATE FUNCTION FN_SOSACHDANGMUON (@MADG CHAR(5))
RETURNS INT
AS
BEGIN
	IF NOT EXISTS (SELECT * FROM DOCGIA WHERE MADG = @MADG)
		RETURN -1

	DECLARE @SOSACH INT
	SELECT @SOSACH = COUNT(*)
	FROM CTPHIEUMUON CT JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
	WHERE PM.MADG = @MADG AND CT.NGAYTRA IS NULL

	RETURN @SOSACH
END
GO

/* ---------------------------------------------------------------------
   FUNCTION 2. Dua vao han tra va ngay tra, tra ve tien phat tra tre.
   Quy dinh: 5.000d cho moi ngay tre. Tra dung han thi tien phat = 0.
   --------------------------------------------------------------------- */
CREATE FUNCTION FN_TIENPHATTRE (@HANTRA DATE, @NGAYTRA DATE)
RETURNS MONEY
AS
BEGIN
	DECLARE @SONGAYTRE INT = DATEDIFF(DAY, @HANTRA, @NGAYTRA)

	IF @SONGAYTRE <= 0
		RETURN 0

	RETURN @SONGAYTRE * 5000
END
GO

/* ---------------------------------------------------------------------
   FUNCTION 3. Dua vao MADG, tra ve bang lich su muon sach cua doc gia:
   ma phieu, ten sach, ngay muon, han tra, ngay tra, so ngay tre,
   trang thai tung cuon.
   --------------------------------------------------------------------- */
CREATE FUNCTION FN_LICHSUMUON (@MADG CHAR(5))
RETURNS TABLE
AS
RETURN
(
	SELECT	PM.MAPM, CS.MACS, DS.TENDS, PM.NGAYMUON, PM.HANTRA, CT.NGAYTRA,
			CASE
				WHEN CT.NGAYTRA IS NULL AND PM.HANTRA < CAST(GETDATE() AS DATE)
					THEN DATEDIFF(DAY, PM.HANTRA, GETDATE())
				WHEN CT.NGAYTRA > PM.HANTRA
					THEN DATEDIFF(DAY, PM.HANTRA, CT.NGAYTRA)
				ELSE 0
			END AS SONGAYTRE,
			CASE
				WHEN CT.NGAYTRA IS NOT NULL THEN N'Đã trả (' + CT.TINHTRANGTRA + N')'
				WHEN PM.HANTRA < CAST(GETDATE() AS DATE) THEN N'Quá hạn'
				ELSE N'Đang mượn'
			END AS TRANGTHAI
	FROM PHIEUMUON PM
		JOIN CTPHIEUMUON CT ON PM.MAPM = CT.MAPM
		JOIN CUONSACH CS ON CT.MACS = CS.MACS
		JOIN DAUSACH DS ON CS.MADS = DS.MADS
	WHERE PM.MADG = @MADG
)
GO

/* ---------------------- VI DU SU DUNG ------------------------------
SELECT dbo.FN_SOSACHDANGMUON('DG007') AS SOSACHDANGMUON
SELECT dbo.FN_TIENPHATTRE('2026-09-15', '2026-09-26') AS TIENPHAT
SELECT * FROM dbo.FN_LICHSUMUON('DG001') ORDER BY NGAYMUON
--------------------------------------------------------------------- */
