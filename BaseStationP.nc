// $Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $

/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * Revision:	$Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $
 */
  
/* 
 * BaseStationP bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the BaseStation, and messages moving from radio to
 * serial will be filtered by that same group id.
 */

#include "AM.h"
#include "Serial.h"
#include "printf.h"
#include "BaseStation.h"
float output_volt = 0, vwc=0, result=0; 
int val;
module BaseStationP @safe() {
  uses {
    interface Boot;
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;
    
    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;

    interface Leds;
  }
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

        
  enum {
    UART_QUEUE_LEN = 12,
    RADIO_QUEUE_LEN = 12,
  };

  message_t  uartQueueBufs[UART_QUEUE_LEN];
  message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
  uint8_t    uartIn, uartOut;
  bool       uartBusy, uartFull;

  message_t  radioQueueBufs[RADIO_QUEUE_LEN];
  message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
  uint8_t    radioIn, radioOut;
  bool       radioBusy, radioFull;

  task void uartSendTask();
  task void radioSendTask();

  void dropBlink() {
    call Leds.led2Toggle();
  }

  void failBlink() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    uint8_t i;

    for (i = 0; i < UART_QUEUE_LEN; i++)
      uartQueue[i] = &uartQueueBufs[i];
    uartIn = uartOut = 0;
    uartBusy = FALSE;
    uartFull = TRUE;

    for (i = 0; i < RADIO_QUEUE_LEN; i++)
      radioQueue[i] = &radioQueueBufs[i];
    radioIn = radioOut = 0;
    radioBusy = FALSE;
    radioFull = TRUE;

    if (call RadioControl.start() == EALREADY)
      radioFull = FALSE;
    if (call SerialControl.start() == EALREADY)
      uartFull = FALSE;
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      radioFull = FALSE;
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      uartFull = FALSE;
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  uint8_t count = 0;

  message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);
  
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(msg, payload, len);
  }
  
  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {



//*********************************************************************//
//If the message is received to base station then extract value from  //
//btrpkt value and put it into temporary variable val and display the //
//values accordingly**************************************************//

      if (len == sizeof(BaseStationMsg))
      {

        BaseStationMsg* btrpkt = (BaseStationMsg*)payload;
        

       printf("Reading:  %u\n", btrpkt->value);   
	val=btrpkt->value;
	 result = (val*2.5)/65535;             //divided by 65535 since val is 16 bit value to make it user readable voltage 
	 output_volt = (val*2.5)/4096;         //calculate output_volt as per formula in the manual.. 4096 as it is 12 bit ADC
	 vwc = (int)(100*(0.000936 * (output_volt * 1000) - 0.376) + 0.5); //calculate volumetric water content as per formula in manual
	 printf("Values from ADC without conversion: %u \n",val);
 	 printf("Actual output_volt readings from soil moisture sensor:");
	 printfFloat(result);
	 printf("\n");
	 printf("Volumetric Water Content: %u \n", vwc);
	 printf("\n");
          
       
    return receive(msg, payload, len);
  }

  message_t* receive(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;

    atomic {
      if (!uartFull)
	{
	  ret = uartQueue[uartIn];
	  uartQueue[uartIn] = msg;

	  uartIn = (uartIn + 1) % UART_QUEUE_LEN;
	
	  if (uartIn == uartOut)
	    uartFull = TRUE;

	  if (!uartBusy)
	    {
	      post uartSendTask();
	      uartBusy = TRUE;
	    }
	}
      else
	dropBlink();
    }
    
    return ret;
  }

  uint8_t tmpLen;
  
  task void uartSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr, src;
    message_t* msg;
    am_group_t grp;
    atomic
      if (uartIn == uartOut && !uartFull)
	{
	  uartBusy = FALSE;
	  return;
	}

    msg = uartQueue[uartOut];
    tmpLen = len = call RadioPacket.payloadLength(msg);
    id = call RadioAMPacket.type(msg);
    addr = call RadioAMPacket.destination(msg);
    src = call RadioAMPacket.source(msg);
    grp = call RadioAMPacket.group(msg);
    call UartPacket.clear(msg);
    call UartAMPacket.setSource(msg, src);
    call UartAMPacket.setGroup(msg, grp);

    if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS)
      call Leds.led1Toggle();
    else
      {
	failBlink();
	post uartSendTask();
      }
  }

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == uartQueue[uartOut])
	  {
	    if (++uartOut >= UART_QUEUE_LEN)
	      uartOut = 0;
	    if (uartFull)
	      uartFull = FALSE;
	  }
    post uartSendTask();
  }

  event message_t *UartReceive.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
    message_t *ret = msg;
    bool reflectToken = FALSE;

    atomic
      if (!radioFull)
	{
	  reflectToken = TRUE;
	  ret = radioQueue[radioIn];
	  radioQueue[radioIn] = msg;
	  if (++radioIn >= RADIO_QUEUE_LEN)
	    radioIn = 0;
	  if (radioIn == radioOut)
	    radioFull = TRUE;

	  if (!radioBusy)
	    {
	      post radioSendTask();
	      radioBusy = TRUE;
	    }
	}
      else
	dropBlink();

    if (reflectToken) {
      //call UartTokenReceive.ReflectToken(Token);
    }
    
    return ret;
  }

  task void radioSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr,source;
    message_t* msg;
    
    atomic
      if (radioIn == radioOut && !radioFull)
	{
	  radioBusy = FALSE;
	  return;
	}

    msg = radioQueue[radioOut];
    len = call UartPacket.payloadLength(msg);
    addr = call UartAMPacket.destination(msg);
    source = call UartAMPacket.source(msg);
    id = call UartAMPacket.type(msg);

    call RadioPacket.clear(msg);
    call RadioAMPacket.setSource(msg, source);
    
    if (call RadioSend.send[id](addr, msg, len) == SUCCESS)
      call Leds.led0Toggle();
    else
      {
	failBlink();
	post radioSendTask();
      }
  }

  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == radioQueue[radioOut])
	  {
	    if (++radioOut >= RADIO_QUEUE_LEN)
	      radioOut = 0;
	    if (radioFull)
	      radioFull = FALSE;
	  }
    
    post radioSendTask();
  }
}  
