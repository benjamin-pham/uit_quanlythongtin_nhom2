/* =====================================================================
   File   : 04_Trigger.sql
   Noi dung: 5 TRIGGER hien thuc cac rang buoc toan ven va nghiep vu
   Luu y  : chay SAU 02_DuLieuMau.sql va 03_Function.sql
   ===================================================================== */

USE QUANLYTHUVIEN
GO

/* ---------------------------------------------------------------------
   TRIGGER 1. Rang buoc thuoc tinh dan xuat:
     DAUSACH.SOLUONG = so cuon sach cua dau sach
     DAUSACH.SLCON   = so cuon sach dang o tinh trang 'Có sẵn'
   Bang tam anh huong:
     | Bang     | Them | Xoa | Sua              |
     | CUONSACH |  +   |  +  | + (MADS, TINHTRANG)|
     | DAUSACH  |  -   |  -  | + (SOLUONG, SLCON) -> khong cho sua tay (CHECK)|
   --------------------------------------------------------------------- */
CREATE TRIGGER TRG_CUONSACH_CAPNHATSL
ON CUONSACH
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON

	UPDATE DAUSACH
	SET SOLUONG = (SELECT COUNT(*) FROM CUONSACH CS WHERE CS.MADS = DAUSACH.MADS),
		SLCON	= (SELECT COUNT(*) FROM CUONSACH CS WHERE CS.MADS = DAUSACH.MADS AND CS.TINHTRANG = N'Có sẵn')
	WHERE MADS IN (SELECT MADS FROM inserted UNION SELECT MADS FROM deleted)
END
GO

/* ---------------------------------------------------------------------
   TRIGGER 2. Dieu kien lap phieu muon:
     - The doc gia phai con han vao ngay muon.
     - Doc gia khong con no tien phat.
     - So ngay muon (HANTRA - NGAYMUON) khong vuot qua so ngay toi da
       cua loai doc gia.
   Bang tam anh huong:
     | Bang       | Them | Xoa | Sua                        |
     | PHIEUMUON  |  +   |  -  | + (MADG, NGAYMUON, HANTRA) |
     | DOCGIA     |  -   |  -  | + (NGAYHETHAN, TONGNO, MALDG) (*) |
     | LOAIDOCGIA |  -   |  -  | + (SONGAYMUON) (*)         |
     (*) chi kiem tra tai thoi diem lap phieu, khong ap dung hoi to.
   --------------------------------------------------------------------- */
CREATE TRIGGER TRG_PHIEUMUON_KIEMTRA
ON PHIEUMUON
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON

	-- Chi kiem tra khi them phieu hoac sua cac cot lien quan
	IF NOT (UPDATE(MADG) OR UPDATE(NGAYMUON) OR UPDATE(HANTRA))
		RETURN

	IF EXISTS (SELECT * FROM inserted I JOIN DOCGIA DG ON I.MADG = DG.MADG
			   WHERE I.NGAYMUON > DG.NGAYHETHAN)
	BEGIN
		RAISERROR (N'Thẻ độc giả đã hết hạn, không thể lập phiếu mượn.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS (SELECT * FROM inserted I JOIN DOCGIA DG ON I.MADG = DG.MADG
			   WHERE DG.TONGNO > 0)
	BEGIN
		RAISERROR (N'Độc giả còn nợ tiền phạt, phải thanh toán trước khi mượn.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS (SELECT * FROM inserted I
					JOIN DOCGIA DG ON I.MADG = DG.MADG
					JOIN LOAIDOCGIA LDG ON DG.MALDG = LDG.MALDG
			   WHERE DATEDIFF(DAY, I.NGAYMUON, I.HANTRA) > LDG.SONGAYMUON)
	BEGIN
		RAISERROR (N'Hạn trả vượt quá số ngày mượn tối đa của loại độc giả.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END
END
GO

/* ---------------------------------------------------------------------
   TRIGGER 3. Muon sach (them chi tiet phieu muon):
     - Cuon sach phai dang o tinh trang 'Có sẵn'.
     - Phieu muon phai o tinh trang 'Đang mượn'.
     - Tong so sach dang muon cua doc gia khong vuot qua SOSACHTOIDA
       cua loai doc gia.
     - Sau khi muon: cap nhat tinh trang cuon sach thanh 'Đang mượn'.
   Bang tam anh huong:
     | Bang        | Them | Xoa | Sua             |
     | CTPHIEUMUON |  +   |  -  | + (MAPM, MACS)  |
     | CUONSACH    |  -   |  -  | + (TINHTRANG)   |
     | LOAIDOCGIA  |  -   |  -  | + (SOSACHTOIDA) (*) |
   --------------------------------------------------------------------- */
CREATE TRIGGER TRG_CTPM_MUONSACH
ON CTPHIEUMUON
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT * FROM inserted I JOIN CUONSACH CS ON I.MACS = CS.MACS
			   WHERE I.NGAYTRA IS NULL AND CS.TINHTRANG <> N'Có sẵn')
	BEGIN
		RAISERROR (N'Có cuốn sách không ở tình trạng "Có sẵn", không thể cho mượn.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	-- Mot cuon sach khong duoc nam trong 2 dong chi tiet chua tra
	IF EXISTS (SELECT CT.MACS FROM CTPHIEUMUON CT
			   WHERE CT.NGAYTRA IS NULL AND CT.MACS IN (SELECT MACS FROM inserted)
			   GROUP BY CT.MACS HAVING COUNT(*) > 1)
	BEGIN
		RAISERROR (N'Một cuốn sách không thể được mượn đồng thời trên nhiều phiếu.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS (SELECT * FROM inserted I JOIN PHIEUMUON PM ON I.MAPM = PM.MAPM
			   WHERE PM.TINHTRANG <> N'Đang mượn')
	BEGIN
		RAISERROR (N'Phiếu mượn đã đóng, không thể thêm sách.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS (SELECT * FROM DOCGIA DG JOIN LOAIDOCGIA LDG ON DG.MALDG = LDG.MALDG
			   WHERE DG.MADG IN (SELECT PM.MADG FROM inserted I JOIN PHIEUMUON PM ON I.MAPM = PM.MAPM)
				 AND dbo.FN_SOSACHDANGMUON(DG.MADG) > LDG.SOSACHTOIDA)
	BEGIN
		RAISERROR (N'Độc giả đã mượn vượt quá số sách tối đa cho phép.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	UPDATE CUONSACH
	SET TINHTRANG = N'Đang mượn'
	WHERE MACS IN (SELECT MACS FROM inserted WHERE NGAYTRA IS NULL)
END
GO

/* ---------------------------------------------------------------------
   TRIGGER 4. Tra sach (cap nhat NGAYTRA trong chi tiet phieu muon):
     - Ngay tra khong duoc truoc ngay muon; sach da tra thi khong sua lai.
     - Cap nhat tinh trang cuon sach theo tinh trang khi tra:
         Bình thường -> Có sẵn | Hư hỏng -> Hư hỏng | Mất -> Mất
     - Tu dong lap phieu phat:
         Tra tre : FN_TIENPHATTRE (5.000d/ngay)
         Hu hong : 50% gia sach
         Mat     : 100% gia sach
     - Phieu muon tra het sach -> tinh trang 'Đã trả'.
   Bang tam anh huong:
     | Bang        | Them | Xoa | Sua                     |
     | CTPHIEUMUON |  -   |  -  | + (NGAYTRA, TINHTRANGTRA) |
     | CUONSACH    |  -   |  -  | + (TINHTRANG)           |
     | PHIEUMUON   |  -   |  -  | + (TINHTRANG)           |
     | PHIEUPHAT   |  +   |  -  | -                       |
   --------------------------------------------------------------------- */
CREATE TRIGGER TRG_CTPM_TRASACH
ON CTPHIEUMUON
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON

	IF NOT (UPDATE(NGAYTRA) OR UPDATE(TINHTRANGTRA))
		RETURN

	IF EXISTS (SELECT * FROM inserted I JOIN deleted D ON I.MAPM = D.MAPM AND I.MACS = D.MACS
			   WHERE D.NGAYTRA IS NOT NULL)
	BEGIN
		RAISERROR (N'Sách đã được trả, không thể cập nhật lại thông tin trả.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS (SELECT * FROM inserted I JOIN PHIEUMUON PM ON I.MAPM = PM.MAPM
			   WHERE I.NGAYTRA < PM.NGAYMUON)
	BEGIN
		RAISERROR (N'Ngày trả không được trước ngày mượn.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	-- Cap nhat tinh trang cuon sach
	UPDATE CS
	SET TINHTRANG = CASE I.TINHTRANGTRA
						WHEN N'Bình thường' THEN N'Có sẵn'
						ELSE I.TINHTRANGTRA
					END
	FROM CUONSACH CS JOIN inserted I ON CS.MACS = I.MACS
	WHERE I.NGAYTRA IS NOT NULL

	-- Lap phieu phat tu dong
	DECLARE @MAX INT
	SELECT @MAX = ISNULL(MAX(CAST(SUBSTRING(MAPP, 3, 4) AS INT)), 0) FROM PHIEUPHAT

	;WITH TRA AS
	(
		SELECT I.MAPM, I.MACS, I.NGAYTRA, I.TINHTRANGTRA, PM.HANTRA, DS.GIA
		FROM inserted I
			JOIN PHIEUMUON PM ON I.MAPM = PM.MAPM
			JOIN CUONSACH CS ON I.MACS = CS.MACS
			JOIN DAUSACH DS ON CS.MADS = DS.MADS
		WHERE I.NGAYTRA IS NOT NULL
	),
	PHAT AS
	(
		SELECT MAPM, MACS, NGAYTRA, N'Trả trễ' AS LYDO, dbo.FN_TIENPHATTRE(HANTRA, NGAYTRA) AS SOTIEN
		FROM TRA WHERE NGAYTRA > HANTRA
		UNION ALL
		SELECT MAPM, MACS, NGAYTRA, N'Hư hỏng', GIA * 0.5
		FROM TRA WHERE TINHTRANGTRA = N'Hư hỏng'
		UNION ALL
		SELECT MAPM, MACS, NGAYTRA, N'Mất sách', GIA
		FROM TRA WHERE TINHTRANGTRA = N'Mất'
	)
	INSERT INTO PHIEUPHAT (MAPP, MAPM, MACS, NGAYLAP, LYDO, SOTIEN, DATHANHTOAN)
	SELECT 'PP' + RIGHT('0000' + CAST(@MAX + ROW_NUMBER() OVER (ORDER BY MAPM, MACS, LYDO) AS VARCHAR(4)), 4),
		   MAPM, MACS, NGAYTRA, LYDO, SOTIEN, 0
	FROM PHAT

	-- Dong phieu muon neu da tra het sach
	UPDATE PHIEUMUON
	SET TINHTRANG = N'Đã trả'
	WHERE MAPM IN (SELECT MAPM FROM inserted)
	  AND NOT EXISTS (SELECT * FROM CTPHIEUMUON CT
					  WHERE CT.MAPM = PHIEUMUON.MAPM AND CT.NGAYTRA IS NULL)
END
GO

/* ---------------------------------------------------------------------
   TRIGGER 5. Rang buoc thuoc tinh dan xuat:
     DOCGIA.TONGNO = tong SOTIEN cac phieu phat chua thanh toan cua doc gia
   Bang tam anh huong:
     | Bang      | Them | Xoa | Sua                         |
     | PHIEUPHAT |  +   |  +  | + (SOTIEN, DATHANHTOAN, MAPM) |
     | DOCGIA    |  -   |  -  | + (TONGNO)                  |
   --------------------------------------------------------------------- */
CREATE TRIGGER TRG_PHIEUPHAT_TONGNO
ON PHIEUPHAT
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON

	UPDATE DOCGIA
	SET TONGNO = ISNULL((SELECT SUM(PP.SOTIEN)
						 FROM PHIEUPHAT PP JOIN PHIEUMUON PM ON PP.MAPM = PM.MAPM
						 WHERE PM.MADG = DOCGIA.MADG AND PP.DATHANHTOAN = 0), 0)
	WHERE MADG IN (SELECT PM.MADG FROM PHIEUMUON PM
				   WHERE PM.MAPM IN (SELECT MAPM FROM inserted UNION SELECT MAPM FROM deleted))
END
GO

/* ---------------------- VI DU KIEM TRA -----------------------------
-- (T2) DG006 the het han 31/08/2026 -> bao loi
INSERT INTO PHIEUMUON VALUES ('PM0099', 'DG006', 'NV02', '2026-09-26', '2026-10-05', N'Đang mượn')
-- (T2) DG009 con no 250.000d -> bao loi
INSERT INTO PHIEUMUON VALUES ('PM0099', 'DG009', 'NV02', '2026-09-26', '2026-10-05', N'Đang mượn')
-- (T3) CS015 da mat -> bao loi
INSERT INTO PHIEUMUON VALUES ('PM0099', 'DG012', 'NV02', '2026-09-26', '2026-10-05', N'Đang mượn')
INSERT INTO CTPHIEUMUON (MAPM, MACS) VALUES ('PM0099', 'CS015')
-- (T4) Tra tre CS011 cua PM0011 -> tu dong lap phieu phat, TONGNO cua DG001 tang
UPDATE CTPHIEUMUON SET NGAYTRA = '2026-09-26', TINHTRANGTRA = N'Bình thường'
WHERE MAPM = 'PM0011' AND MACS = 'CS011'
SELECT * FROM PHIEUPHAT WHERE MAPM = 'PM0011'
SELECT MADG, TONGNO FROM DOCGIA WHERE MADG = 'DG001'
--------------------------------------------------------------------- */
