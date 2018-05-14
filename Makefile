COMPONENT=MoistSensorAppC
BUILD_EXTRA_DEPS=MoistSensorMsg.class
MoistSensorMsg.class: MoistSensorMsg.java
	javac MoistSensorMsg.java
MoistSensorMsg.java:
	mig java -target=null -java-classname=MoistSensorMsg MoistSensor.h MoistSensorMsg -o $@
PFLAGS += -I ./mda300ca
CFLAGS += -I$(TOSDIR)/lib/printf
include $(MAKERULES)
PFLAGS+=-DCC2420_DEF_CHANNEL=20
