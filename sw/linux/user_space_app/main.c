#include<stdio.h>
#include<stdlib.h>
#include<errno.h>
#include<fcntl.h>
#include<string.h>
#include<unistd.h>
#include <sys/ioctl.h>
#include <signal.h>
 
#define ZED_IO_MAGIC 81


#define ZED_IO_INT_SET       _IOW(ZED_IO_MAGIC, 1, int)
#define ZED_IO_INT_CLR       _IOW(ZED_IO_MAGIC, 2, int)
#define ZED_IO_INT_BUTT_EDGE _IOW(ZED_IO_MAGIC, 3, int)
#define ZED_IO_DEB_ENA       _IOW(ZED_IO_MAGIC, 4, int)
#define ZED_IO_DEB_TIM       _IOW(ZED_IO_MAGIC, 5, int)
#define ZED_IO_USER_SIG      _IOW(ZED_IO_MAGIC, 6, int)

#define SIGETX 44

volatile unsigned int interrupt_val;
char interrupt_led;
int fd;

// interrupt handler for signal 
void sig_event_handler(int n, siginfo_t *info, void *unused)
{
    if (n == SIGETX) {
        read(fd, (void*) &interrupt_val, 1); // read data from register
        interrupt_led = (char) interrupt_val;
        write(fd, &interrupt_led, 1); // read button status
        
        printf ("Button status :   %u\n", interrupt_val);
    }
}

int main(){
   int ret;
   struct sigaction act;
   sigset_t signal_set;
   int i;
   unsigned int data_val[9];
   char led[10];
   led[0] = 0xff;
   int *signal;
   
    /* install custom signal handler */
    sigemptyset(&act.sa_mask);
    act.sa_flags = (SA_SIGINFO | SA_RESTART);
    act.sa_sigaction = sig_event_handler;
    sigaction(SIGETX, &act, NULL);

   //sigemptyset(&signal_set);
   //sigaddset(&signal_set, SIGETX);
   
   printf("Starting device test code example...\n");
   fd = open("/dev/zed_io", O_RDWR);             // Open the device with read/write access
   if (fd < 0){
      perror("Failed to open the device...");
      return errno;
   }

   printf("IOCTL\n");
   ret = ioctl(fd, ZED_IO_INT_SET, 0x00ff); // set interrupt for button
   printf("ret:%d ioctl comm 0.\n", ret);   
   
   ret = ioctl(fd, ZED_IO_INT_BUTT_EDGE, 31);
   printf("ret:%d ioctl comm 1.\n", ret);
   
   ret = ioctl(fd, ZED_IO_DEB_ENA, 0x1fff);   
   printf("ret:%d ioctl comm 2.\n", ret);  
      
   ret = ioctl(fd, ZED_IO_DEB_TIM, 1);
   printf("ret:%d ioctl comm 3.\n", ret);
      
   ret = ioctl(fd, ZED_IO_USER_SIG, 1);  // give pid of user app to driver 
   
   ret = read(fd, (void*) data_val, 9); // read data from register
   if (ret < 0){
      perror("Failed to read the message to the device.");
      return errno;
   }   
   
   for (i = 0; i < 9; i++) {
     printf("data[%d]: %X\n", i, data_val[i]);
   }   
   
   printf("writing and probing....");
   write(fd, led, strlen(led));
   
   // it is possible alos use wait for signal instead of signal handled
   //sigwait( &signal_set, signal  );
   
   while(1) {
    sleep(1);    
   }
   
   printf("End of the program\n");
   return 0;
}
