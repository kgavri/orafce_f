MODULE_big = orafce
OBJS= convert.o file.o datefce.o magic.o others.o plvstr.o plvdate.o shmmc.o plvsubst.o utility.o plvlex.o alert.o pipe.o sqlparse.o putline.o assert.o plunit.o random.o aggregate.o oraguc.o varchar2.o nvarchar2.o

EXTENSION = orafce

DATA_built = orafce.sql
DATA = uninstall_orafce.sql orafce--3.0.7.sql orafce--unpackaged--3.0.7.sql
DOCS = README.asciidoc COPYRIGHT.orafce INSTALL.orafce

PG_CONFIG ?= pg_config

# version as a number, e.g. 9.1.4 -> 901
VERSION := $(shell $(PG_CONFIG) --version | awk '{print $$2}')
INTVERSION := $(shell echo $$(($$(echo $(VERSION) | sed 's/\([[:digit:]]\{1,\}\)\.\([[:digit:]]\{1,\}\).*/\1*100+\2/' ))))

# make "all" the default target
all:

REGRESS = orafce dbms_output dbms_utility files varchar2 nvarchar2

ifeq ($(shell echo $$(($(INTVERSION) >= 804))),1)
REGRESS += aggregates nlssort dbms_random
endif

REGRESS_OPTS = --load-language=plpgsql --schedule=parallel_schedule
REGRESSION_EXPECTED = expected/orafce.out expected/dbms_pipe_session_B.out

ifeq ($(shell echo $$(($(INTVERSION) <= 802))),1)
$(REGRESSION_EXPECTED): %.out: %1.out
	cp $< $@
else
$(REGRESSION_EXPECTED): %.out: %2.out
	cp $< $@
endif

installcheck: $(REGRESSION_EXPECTED)

EXTRA_CLEAN = sqlparse.c sqlparse.h sqlscan.c y.tab.c y.tab.h orafce.sql.in expected/orafce.out expected/dbms_pipe_session_B.out

ifndef USE_PGXS
top_builddir = ../..
makefile_global = $(top_builddir)/src/Makefile.global
ifeq "$(wildcard $(makefile_global))" ""
USE_PGXS = 1	# use pgxs if not in contrib directory
endif
endif

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/$(MODULE_big)
include $(makefile_global)
include $(top_srcdir)/contrib/contrib-global.mk
endif

ifeq ($(enable_nls), yes)
ifeq ($(PORTNAME),win32)
SHLIB_LINK += -lintl
else
SHLIB_LINK += -L$(libdir)/gettextlib
endif
endif

# remove dependency to libxml2 and libxslt
LIBS := $(filter-out -lxml2, $(LIBS))
LIBS := $(filter-out -lxslt, $(LIBS))

plvlex.o: sqlparse.o

sqlparse.o: $(srcdir)/sqlscan.c

$(srcdir)/sqlparse.h: $(srcdir)/sqlparse.c ;

$(srcdir)/sqlparse.c: sqlparse.y
ifdef BISON
	$(BISON) -d $(BISONFLAGS) -o $@ $<
else
ifdef YACC
	$(YACC) -d $(YFLAGS) -p cube_yy $<
	mv -f y.tab.c sqlparse.c
	mv -f y.tab.h sqlparse.h
else
	bison -d $(BISONFLAGS) -o $@ $<
endif
endif

$(srcdir)/sqlscan.c: sqlscan.l
ifdef FLEX
	$(FLEX) $(FLEXFLAGS) -o'$@' $<
else
	flex $(FLEXFLAGS) -o'$@' $<
endif

distprep: $(srcdir)/sqlparse.c $(srcdir)/sqlscan.c

maintainer-clean:
	rm -f $(srcdir)/sqlparse.c $(srcdir)/sqlscan.c

ifndef MAJORVERSION
MAJORVERSION := $(basename $(VERSION))
endif

orafce.sql.in:
	if [ -f orafce-$(MAJORVERSION).sql ] ; \
	then \
	cat orafce-common.sql orafce-$(MAJORVERSION).sql > orafce.sql.in; \
	else \
	cat orafce-common.sql orafce-common-2.sql > orafce.sql.in; \
	fi
