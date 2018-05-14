#include "Timer.h"
#include "printf.h"
#include "mda300.h"
float output_volt = 0, vwc=0, result=0;  
 
 module MoistSensorC {
   uses interface Boot;
   uses interface Leds;
   uses interface Timer<TMilli> as Timer0;  
   uses interface Timer<TMilli> as Timer1;
   uses interface Packet;
   uses interface AMPacket;
   uses interface AMSend;
   uses interface Receive;
   uses interface SplitControl as AMControl;
   uses interface GeneralIO as TWO_HALF_VOLT;
   uses interface GeneralIO as FIVE_VOLT;
   uses interface Read<uint16_t> as MoistSensor;
 }



 implementation 
 {
	
/****** Function to have float values with 2 decimal places taken from
// http://balajipcse.blogspot.com/2011/11/tinyos-and-float-numbers.html
// with minor modifications********************************************/
    
     void printfFloat(float toBePrinted) 
     {
       uint32_t fi, f0, f1, f2, f3, f4;
       float f = toBePrinted; //1.53

      // integer portion.
      fi = (uint32_t) f; //1

      // decimal portion...get index for up to 2 decimal places.
      f0 = f - ((float) fi); //0.53
      f1=  f0*10; //5.3
      f2= (uint32_t) f1; //5
      f3= f1-f2; //0.3
      f4= f3*10; //3
     
      printf("%ld.%d%d", fi, (uint8_t) f2, (uint8_t) f4);
     }

     uint16_t value = 0;
     bool busy = FALSE;
     message_t pkt;


/*******Initialization of timers for pump and moisture sensor****************/
    event void AMControl.startDone(error_t err)
    {
    	if (err == SUCCESS) 
        {
      		call Timer0.startPeriodic(1000);
		call Timer1.startPeriodic(1000);
    	}
        else 
	{
                call AMControl.start();    //else retry again
        }
    }
  
  

/**********Send-done handler to indicate that message has been sent and the buffer**********/
/************ can be reused by clearing the busy flag*****************/
     event void AMSend.sendDone(message_t* msg, error_t error) 
     {
    	if (&pkt == msg) 
	{
      		busy = FALSE;
        }
     }

     event void AMControl.stopDone(error_t err) 
     {
     }
 
     event void Boot.booted() 
     {
	call TWO_HALF_VOLT.set();   		//excitation voltage for moisture sensor.
	call FIVE_VOLT.set();       		//excitation voltage for activating pump.
        call Timer0.startPeriodic(1000);
	call Timer1.startPeriodic(1000);
     	call AMControl.start();
     }

/******Timer fired and and sensor is read**********************/
     event void Timer0.fired() 
     {
        call MoistSensor.read();
  
     }

/******Timer fired and excitation given to pump**********************/
     event void Timer1.fired()
     {
	call FIVE_VOLT.set();
     }

 
/******Sensor read is done from ADC and stored in val********************/    
     event void MoistSensor.readDone(error_t result, uint16_t val)    //ADC pin is read into 16 bit val
     {
	 result = (val*2.5)/65535;             //divided by 65535 since val is 16 bit value to make it user readable voltage 
	 output_volt = (val*2.5)/4096;         //calculate output_volt as per formula in the manual.. 4096 as it is 12 bit ADC
	 vwc = (int)(100*(0.000936 * (output_volt * 1000) - 0.376) + 0.5); //calculate volumetric water content as per formula in manual
	 printf("Values from ADC without conversion: %u \n",val);
 	 printf("Actual output_volt readings from soil moisture sensor:");
	 printfFloat(result);
	 printf("\n");
	 printf("Volumetric Water Content: %u \n", vwc);
	 printf("\n");
	 if (!busy)                            //packet transmission not in progress//
         {
   		MoistSensorMsg* btrpkt = (MoistSensorMsg*)(call Packet.getPayload(&pkt, sizeof (MoistSensorMsg))); 
		 //casts the packet payload portion to MoistSensor with value
    		btrpkt->value = val;    //val from ADC is read into value and sent to base-station
	        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MoistSensorMsg)) == SUCCESS) 
                {
      			busy = TRUE;
		//sends the packet with  AM_BROADCAST_ADDR as destination address and updates busy flag//
       		}
     		}
		
		if (result == SUCCESS) 
		call Leds.led1Toggle();   //if the value is read successfully then toggle green led
		
/********Excitation of 5 V from MDA-300 to turn on and off the motor after some threshold***********/
		if ((val)<30000)          //dry soil       
		{
		call FIVE_VOLT.set();     //turn on motor
		call Timer1.startPeriodic(1000);
		}
		if ((val)>30000)         //wet soil
		{ 
		call FIVE_VOLT.clr();   //turn off motor
		call Timer1.startPeriodic(1000);
		}
	  }
   }
 
 
 
 
 
 
 

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
