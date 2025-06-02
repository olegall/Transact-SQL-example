CREATE TABLE Balance
(	
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	GoodsId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Goods(Id),
	Count INT NOT NULL,
	Sum FLOAT NOT NULL
);

CREATE TABLE Currency
(	
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	Title VARCHAR(50) NOT NULL
);

CREATE TABLE CurrencyRate
(	
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	CurrencyId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Currency(Id),
	Date DATETIME NOT NULL,
	Rate FLOAT NOT NULL
);

CREATE TABLE Goods
(
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,	
	Title VARCHAR(50) NOT NULL,
	Price FLOAT NOT NULL
)

CREATE TABLE Income
(
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	Num INT NOT NULL,
	Date DATETIME NOT NULL,
	StorageId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Storage(Id),
	CurrencyId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Currency(Id),
	OrganizationId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Organization(Id),
	StringNum INT NOT NULL,
	GoodsId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Goods(Id),
	Count INT NOT NULL,
	Price FLOAT NOT NULL,
	Sum FLOAT NOT NULL
)

CREATE TABLE Organization
(	
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	Title VARCHAR(50) NOT NULL
);

CREATE TABLE Outcome
(
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	Num INT NOT NULL,
	Date DATETIME NOT NULL,
	StorageId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Storage(Id),
	CurrencyId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Currency(Id),
	OrganizationId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Organization(Id),
	StringNum INT NOT NULL,
	GoodsId UNIQUEIDENTIFIER FOREIGN KEY REFERENCES Goods(Id),
	Count INT NOT NULL,
	Price FLOAT NOT NULL,
	Sum FLOAT NOT NULL
)

CREATE TABLE Storage
(	
	Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	Title VARCHAR(50) NOT NULL
);




USE [1gb_city-move];
GO  
ALTER PROCEDURE uspSaveIncome @xml as XML
AS  
	DECLARE @num int = @xml.value('(/income[1]/@num)', 'int');
	DECLARE @date datetime = @xml.value('(/income[1]/@date)', 'datetime');
	DECLARE @storageId uniqueidentifier = @xml.value('(/income[1]/@storageId)', 'uniqueidentifier');
	DECLARE @currencyId uniqueidentifier = @xml.value('(/income[1]/@currencyId)', 'uniqueidentifier');
	DECLARE @organizationId uniqueidentifier = @xml.value('(/income[1]/@organizationId)', 'uniqueidentifier');

	DECLARE @detalizationTagsCount int = @xml.value('count(/income/detalization)', 'int');
	DECLARE @counter int = 1;
	BEGIN TRANSACTION
		WHILE (@counter <= @detalizationTagsCount)
		BEGIN

			DECLARE @stringNum int = @xml.value('(/income/detalization[sql:variable("@counter")]/@stringNum)[1]', 'int');
			DECLARE @goodsId uniqueidentifier = @xml.value('(/income/detalization[sql:variable("@counter")]/@goodsId)[1]', 'uniqueidentifier');
			DECLARE @goodsPrice float = (SELECT Price FROM Goods WHERE Id = @goodsId);

			DECLARE @xmlPrice float =  @xml.value('(/income/detalization[sql:variable("@counter")]/@goodsPrice)[1]', 'float');
			DECLARE @rate float = (SELECT Rate FROM CurrencyRate WHERE CurrencyId = @currencyId AND Date = @date);
			UPDATE Goods SET Price = @rate * @xmlPrice WHERE Id = @goodsId;
			
			DECLARE @goodsCount int = @xml.value('(/income/detalization[sql:variable("@counter")]/@goodsCount)[1]', 'int');
			DECLARE @goodsSum float = @goodsPrice * @goodsCount;

			IF NOT EXISTS (SELECT * FROM Goods WHERE Id = @goodsId)
				THROW 50000, 'Вы пытаетесь добавить в приход товар, которого нет в таблице Goods. Сначала добавьте его в таблицу Goods', 1;

			INSERT INTO Income (Id,      Date,  Num,  StorageId,  CurrencyId,  OrganizationId,  StringNum,   GoodsId, Count,   Price,   Sum) 
			VALUES			   (NEWID(), @date, @num, @storageId, @currencyId, @organizationId, @stringNum, @goodsId, @goodsCount, @goodsPrice, @goodsSum)

			IF EXISTS (SELECT * FROM Balance WHERE GoodsId = @goodsId)
			BEGIN
				DECLARE @balanceGoodsCount int;
				DECLARE @balanceGoodsSum float;
				SELECT @balanceGoodsCount = Count, @balanceGoodsSum = Sum FROM Balance WHERE GoodsId = @goodsId;
				
				UPDATE Balance SET Count = @balanceGoodsCount + @goodsCount, Sum = @balanceGoodsSum + @goodsSum WHERE GoodsId = @goodsId
			END
			ELSE
			BEGIN
				INSERT INTO Balance (Id, GoodsId, Count, Sum) VALUES (NEWID(), @goodsId, @goodsCount, @goodsSum)
			END

			SET @counter = @counter + 1;
		END
	COMMIT
GO

DECLARE @xml xml = 
'<income num="1" date="2018-02-11T08:30:00" storageId="08B6B2FB-0F39-4C44-B9A1-965FD4884314" 
                                            currencyId="73F9DA5C-12CE-4B94-AF49-B52736A9C311" 
											organizationId="79B159A3-E11A-4B78-BD63-6EC1D7707D17">
    <detalization stringNum="1" goodsId="C34661B0-93C9-40C6-AEEB-158074AE5E90" goodsPrice="0.7" goodsCount="100"/>
	<detalization stringNum="2" goodsId="CE6F9A26-E24A-452D-B73D-2EACA904D683" goodsPrice="0.8" goodsCount="70"/>
	<detalization stringNum="3" goodsId="A1C117A0-295D-42C8-9C7C-76F11279EA35" goodsPrice="1" goodsCount="80"/>
</income>'
EXEC uspSaveIncome @xml



USE [1gb_city-move];
GO  
ALTER PROCEDURE uspSaveOutcome @xml as XML
AS  
	DECLARE @num int = @xml.value('(/outcome[1]/@num)', 'int');
	DECLARE @date datetime = @xml.value('(/outcome[1]/@date)', 'datetime');
	DECLARE @storageId uniqueidentifier = @xml.value('(/outcome[1]/@storageId)', 'uniqueidentifier');
	DECLARE @currencyId uniqueidentifier = @xml.value('(/outcome[1]/@currencyId)', 'uniqueidentifier');
	DECLARE @organizationId uniqueidentifier = @xml.value('(/outcome[1]/@organizationId)', 'uniqueidentifier');

	DECLARE @detalizationTagsCount int = @xml.value('count(/outcome/detalization)', 'int');
	DECLARE @counter int = 1;
	
	BEGIN TRY
		BEGIN TRANSACTION
			WHILE (@counter <= @detalizationTagsCount)
			BEGIN
				DECLARE @goodsId uniqueidentifier = @xml.value('(/outcome/detalization[sql:variable("@counter")]/@goodsId)[1]', 'uniqueidentifier');
				IF EXISTS (SELECT * FROM Balance WHERE GoodsId = @goodsId)
				BEGIN
					DECLARE @balanceGoodsCount int;
					DECLARE @balanceGoodsSum float;
					SELECT @balanceGoodsCount = Count, @balanceGoodsSum = Sum FROM Balance WHERE GoodsId = @goodsId;

					DECLARE @goodsCount int = @xml.value('(/outcome/detalization[sql:variable("@counter")]/@goodsCount)[1]', 'int');
				
					IF (@balanceGoodsCount - @goodsCount < 0)
						THROW 50000, 'Вы пытаетесь забрать товара больше, чем есть на складе. Возьмите меньше товара', 1;

					DECLARE @stringNum int = @xml.value('(/outcome/detalization[sql:variable("@counter")]/@stringNum)[1]', 'int');
					DECLARE @goodsPrice float = (SELECT Price FROM Goods WHERE Id = @goodsId);
					DECLARE @goodsSum float = @goodsCount * (@balanceGoodsSum / @balanceGoodsCount);
					
					INSERT INTO Outcome (Id,      Date,  Num,  StorageId,  CurrencyId,  OrganizationId,  StringNum,   GoodsId, Count,   Price,   Sum) 
					VALUES			   (NEWID(), @date, @num, @storageId, @currencyId, @organizationId, @stringNum, @goodsId, @goodsCount, @goodsPrice, @goodsSum)

					UPDATE Balance SET Count = @balanceGoodsCount - @goodsCount, Sum = @balanceGoodsSum - @goodsSum WHERE GoodsId = @goodsId
				END
				ELSE
					THROW 50000, 'Вы пытаетесь забрать товар, которого нет на складе', 1;

				SET @counter = @counter + 1;
			END
		COMMIT
	END TRY
	BEGIN CATCH
		ROLLBACK;
	END CATCH
GO

DECLARE @xml xml = 
'<outcome num="1" date="2018-03-11T14:00:00" storageId="08B6B2FB-0F39-4C44-B9A1-965FD4884314" 
                                            currencyId="73F9DA5C-12CE-4B94-AF49-B52736A9C311" 
											organizationId="53B279AB-95EC-41FA-BF9F-CBA48DA49E17">
    <detalization stringNum="1" goodsId="C34661B0-93C9-40C6-AEEB-158074AE5E90" goodsCount="10"/>
</outcome>'
EXEC uspSaveOutcome @xml 