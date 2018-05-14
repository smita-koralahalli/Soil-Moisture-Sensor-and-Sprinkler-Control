#ifndef BASESTATION_H
#define BaSESTATION_H

 enum {
  AM_BASESTATIONMSG = 6,
  TIMER_PERIOD_MILLI = 1000
 };
 
 typedef nx_struct BaseStationMsg {
 nx_uint16_t value;
} BaseStationMsg;
 

#endif
