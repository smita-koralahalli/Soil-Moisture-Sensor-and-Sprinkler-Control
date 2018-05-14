#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "Timer.h"
#include "mda300.h"

configuration MoistSensorAppC
{
}

implementation
{       
	/*****Initialization of components*********************/
	components MainC, MoistSensorC as App, LedsC;
	components new TimerMilliC() as Timer0;
	components new TimerMilliC() as Timer1;
	components ActiveMessageC;
  	components new AMSenderC(AM_MoistSensorMSG);
	
	#ifdef NEW_PRINTF_SEMANTICS
	components PrintfC;
	components SerialStartC;
	#endif
	
	components MicaBusC;
	components new SensorMDA300CA() as Mda300;
	
	App -> MainC.Boot;
	App.Timer0 -> Timer0;             //Timer 1 and Timer 2 initialization
	App.Timer1 -> Timer1;
	App.Leds -> LedsC;

	App.Packet -> AMSenderC;
  	App.AMPacket -> AMSenderC;
        App.AMSend -> AMSenderC;
        App.AMControl -> ActiveMessageC;
        
	App.TWO_HALF_VOLT -> MicaBusC.PW2;  //2.5 volt initialization
	App.FIVE_VOLT -> MicaBusC.PW5;      //5 volt initialization
	
	App.MoistSensor -> Mda300.ADC_3; // Output from the soil moisture sensor read into ADC pin 3 of MDA300
}



 

 
 


