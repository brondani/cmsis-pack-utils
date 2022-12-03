// Copyright (c) 2022 Arm Limited and Contributors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include "cmsis_os2.h"
#include "EventRecorder.h"                          // Keil::Compiler:Event Messaging

void thread_func(void *argument) {
  for (int itr = 1; itr < 10; ++itr) {
    printf("Hello world : %d\n\r", itr);
  }
}

int main(void) {
  EventRecorderInitialize (EventRecordAll, 1);      // initialize and start Event Recorder
  osThreadNew(thread_func, NULL, NULL);
  if (osKernelReady == osKernelGetState()) {
    osKernelStart();
  }

  while (1);
}
