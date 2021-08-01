SET IDENTITY_INSERT dbo.pcx_ISOEarthquake_Ext			  ON
SET IDENTITY_INSERT dbo.pcx_ISOEarthquakeZip_Ext		  ON
SET IDENTITY_INSERT dbo.pcx_ISOPPC_Ext					  ON
SET IDENTITY_INSERT dbo.pcx_ISOPPCZip_Ext				  ON
SET IDENTITY_INSERT dbo.pcx_ISOPPCZipDC_Ext				  ON
SET IDENTITY_INSERT dbo.pcx_ISOTax_Ext					  ON
SET IDENTITY_INSERT dbo.pcx_ISOTaxDetail_Ext			  ON
SET IDENTITY_INSERT dbo.pcx_ISOTaxDetailLOBValue_Ext	  ON
SET IDENTITY_INSERT dbo.pcx_ISOTaxZip_Ext				  ON
SET IDENTITY_INSERT dbo.pcx_ISOTerritory_Ext			  ON
SET IDENTITY_INSERT dbo.pcx_ISOTerritoryZip_Ext           ON



INSERT pcx_ISOEarthquake_Ext (LoadCommandID,Post,Zip,High,Pre,Street,PublicID,FIPS,BeanVersion,City,OEB,State,Low,Type,EarthquakeCode,ID) 
SELECT LoadCommandID,Post,Zip,High,Pre,Street,PublicID,FIPS,BeanVersion,City,OEB,State,Low,Type,EarthquakeCode,ID FROM pcx_ISOEarthquake_Ext_TMP11222019

INSERT pcx_ISOEarthquakeZip_Ext       ( LoadCommandID,Pct,Zip,State,PublicID,BeanVersion,EarthquakeCode,ID,MRC) SELECT * FROM                                                                                               pcx_ISOEarthquakeZip_Ext_TMP11222019
INSERT pcx_ISOPPC_Ext                 ( LoadCommandID,Sub,Street,PublicID,FIPS,OEB,FS,Alt_PPC,State,WaterType,Low,Alt_DC,FPA,ID,TrackNum,MRC,Post,SS,Zip,High,Spind,Pre,PPC,BeanVersion,City,Band,Type,DC) SELECT * FROM 	pcx_ISOPPC_Ext_TMP11222019
INSERT pcx_ISOPPCZip_Ext              ( SS,Sub,LoadCommandID,Zip,Pct,PPC,PublicID,FIPS,BeanVersion,State,FPA,ID,MRC) SELECT * FROM 																							pcx_ISOPPCZip_Ext_TMP11222019
INSERT pcx_ISOPPCZipDC_Ext            ( SS,Sub,LoadCommandID,Zip,Pct,PublicID,FIPS,BeanVersion,State,FPA,ID,MRC,DC) SELECT * FROM 																							pcx_ISOPPCZipDC_Ext_TMP11222019
INSERT pcx_ISOTax_Ext                 ( LoadCommandID,Post,Zip,High,Pre,Street,PublicID,Match,FIPS,BeanVersion,RevisionDate,City,OEB,State,TerritoryType,Low,TaxCode,Type,ID,MRC) SELECT * FROM 							pcx_ISOTax_Ext_TMP11222019
INSERT pcx_ISOTaxDetail_Ext           ( LoadCommandID,State,PublicID,TerritoryType,LobTaxValue,BeanVersion,TaxCode,LobID,ID) SELECT * FROM 																					pcx_ISOTaxDetail_Ext_TMP11222019
INSERT pcx_ISOTaxDetailLOBValue_Ext   ( LoadCommandID,State,PublicID,TerritoryType,LobTaxValue,BeanVersion,TaxCode,LobID,ID) SELECT * FROM 																					pcx_ISOTaxDetailLOBValue_Ext_TMP11222019
INSERT pcx_ISOTaxZip_Ext              ( LoadCommandID,Pct,Zip,State,PublicID,TerritoryType,BeanVersion,TaxCode,ID,MRC) SELECT * FROM 																						pcx_ISOTaxZip_Ext_TMP11222019
INSERT pcx_ISOTerritory_Ext           ( LoadCommandID,Post,Zip,High,Pre,Street,PublicID,FIPS,TerritoryCode,BeanVersion,City,OEB,State,Low,Type,ID) SELECT * FROM 															pcx_ISOTerritory_Ext_TMP11222019
INSERT pcx_ISOTerritoryZip_Ext        ( LoadCommandID,Pct,Zip,State,PublicID,TerritoryCode,BeanVersion,ID,MRC																												pcx_ISOTerritoryZip_Ext_TMP11222019


SET IDENTITY_INSERT dbo.pcx_ISOEarthquake_Ext			  OFF
SET IDENTITY_INSERT dbo.pcx_ISOEarthquakeZip_Ext		  OFF
SET IDENTITY_INSERT dbo.pcx_ISOPPC_Ext					  OFF
SET IDENTITY_INSERT dbo.pcx_ISOPPCZip_Ext				  OFF
SET IDENTITY_INSERT dbo.pcx_ISOPPCZipDC_Ext				  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTax_Ext					  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTaxDetail_Ext			  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTaxDetailLOBValue_Ext	  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTaxZip_Ext				  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTerritory_Ext			  OFF
SET IDENTITY_INSERT dbo.pcx_ISOTerritoryZip_Ext           OFF
