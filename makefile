
BIN_LIB=ILEUSION
DBGVIEW=*ALL
MODS=$(BIN_LIB)/ACTIONS $(BIN_LIB)/DATA $(BIN_LIB)/CALLFUNC $(BIN_LIB)/TYPES
 
TESTS=$(patsubst %.rpgle,%.test,$(notdir $(shell ls tests/*.rpgle)))

# ---------------

.ONESHELL:

all: clean $(BIN_LIB).lib ileusion_s.srvpgm ileusion_f.sql
	@echo "Build finished!"

%.lib:
	-system -q "CRTLIB $* TYPE(*PROD) TEXT('ILEusion')"

ileusion_s.srvpgm: ileusion_s.rpgle actions.rpgle data.rpgle callfunc.rpgle types.c

%.srvpgm:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -s "CRTSRVPGM SRVPGM($(BIN_LIB)/$*) MODULE($(BIN_LIB)/$* $(MODS)) EXPORT(*ALL) ACTGRP(*CALLER) BNDSRVPGM((NOXDB/JSONXML))"
	EOF

%.sql:
	system "RUNSQLSTM SRCSTMF('./src/$*.sql') COMMIT(*NONE) DFTRDBCOL($(BIN_LIB)) NAMING(*SYS)" 

%.rpgle:
	system -s "CHGATR OBJ('./src/$*.rpgle') ATR(*CCSID) VALUE(1252)"
	system -s "CRTRPGMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"
	
%.c:
	system "CRTCMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.c') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"

tests: $(TESTS)
	-system -s "CRTDTAQ DTAQ(ILEUSION/TESTDQ) MAXLEN(100)"
	@echo "Tests built!"

%.test:
	system -s "CHGATR OBJ('./tests/$*.rpgle') ATR(*CCSID) VALUE(1252)"
	system -s "CRTBNDRPG PGM($(BIN_LIB)/$*) SRCSTMF('./tests/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"

testcalls:
	db2util "select ileusion.ILEUSION_CALL(cast('[{\"action\": \"/call\", \"object\":\"FAK100\",\"library\":\"ILEUSION\",\"args\":[{\"value\":\"John\",\"type\":\"char\",\"length\":20},{\"value\":11,\"type\":\"int\",\"length\":10},{\"value\":8,\"type\":\"int\",\"length\":10},{\"value\":0,\"type\":\"int\",\"length\":10}]}]' as char(1024))) from sysibm.sysdummy1;"
	db2util "select ileusion.ILEUSION_CALL(cast('[{\"action\": \"/call\", \"object\":\"FAK101\",\"library\":\"ILEUSION\",\"args\":[{\"value\":\"Dave\",\"type\":\"char\",\"length\":20},{\"values\":[3,3,5],\"type\":\"int\",\"length\":10}]}]' as char(1024))) from sysibm.sysdummy1;"
	db2util "select ileusion.ILEUSION_CALL(cast('[{\"action\":\"/dq/send\",\"library\":\"ILEUSION\",\"object\":\"TESTDQ\",\"data\":\"Hello world\"},{\"action\":\"/dq/pop\",\"library\":\"ILEUSION\",\"object\":\"TESTDQ\",\"length\":20}]' as char(1024))) from sysibm.sysdummy1;"
	db2util "select ileusion.ILEUSION_CALL(cast('[{\"action\":\"/call\",\"library\":\"ILEUSION\",\"object\":\"DS1\",\"args\":[{\"type\":\"struct\",\"value\":[{\"type\":\"char\",\"length\":20,\"value\":\"Liam\"},{\"type\":\"int\",\"length\":3,\"value\":11},{\"type\":\"packed\",\"length\":11,\"precision\":2,\"value\":12.34}]}]}]' as char(1024))) from sysibm.sysdummy1;"

clean:
	-system -s "DLTOBJ OBJ($(BIN_LIB)/*ALL) OBJTYPE(*FILE)"
	-system -s "DLTOBJ OBJ($(BIN_LIB)/*ALL) OBJTYPE(*MODULE)"
	
release: clean
	@echo " -- Creating ILEusion release. --"
	@echo " -- Copying service programs deps. --"
	system "CRTDUPOBJ OBJ(ILEASTIC) FROMLIB(ILEASTIC) OBJTYPE(*SRVPGM) TOLIB($(BIN_LIB))"
	system "CRTDUPOBJ OBJ(JSONXML) FROMLIB(NOXDB) OBJTYPE(*SRVPGM) TOLIB($(BIN_LIB))"
	@echo " -- Creating save file. --"
	system "CRTSAVF FILE($(BIN_LIB)/RELEASE)"
	system "SAVLIB LIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE) OMITOBJ((RELEASE *FILE))"
	-rm -r release
	-mkdir release
	system "CPYTOSTMF FROMMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') TOSTMF('./release/release.savf') STMFOPT(*REPLACE) STMFCCSID(1252) CVTDTA(*NONE)"
	@echo " -- Cleaning up... --"
	system "DLTOBJ OBJ($(BIN_LIB)/RELEASE) OBJTYPE(*FILE)"
	system "DLTOBJ OBJ($(BIN_LIB)/ILEASTIC) OBJTYPE(*SRVPGM)"
	system "DLTOBJ OBJ($(BIN_LIB)/JSONXML) OBJTYPE(*SRVPGM)"
	@echo " -- Release created! --"
	@echo ""
	@echo "To install the release, run:"
	@echo "  > CRTLIB $(BIN_LIB)"
	@echo "  > CPYFRMSTMF FROMSTMF('./release/release.savf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') MBROPT(*REPLACE) CVTDTA(*NONE)"
	@echo "  > RSTLIB SAVLIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE)"
	@echo ""
