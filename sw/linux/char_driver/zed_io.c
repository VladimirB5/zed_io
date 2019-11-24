// insipired by article writing a linux kernel module by Derek Molloy (derekmolloy.ie)
// and linux device drivers 3rd edition

#include <linux/init.h>           // Macros used to mark up functions e.g. __init __exit
#include <linux/module.h>         // Core header for loading LKMs into the kernel
#include <linux/device.h>         // Header to support the kernel Driver Model
#include <linux/kernel.h>         // Contains types, macros, functions for the kernel
#include <linux/fs.h>             // Header for the Linux file system support
#include <linux/uaccess.h>          // Required for the copy to user function
#include <linux/ioport.h>
#include <asm/io.h>
#include <asm/current.h>
#include <linux/interrupt.h>            // Required for the IRQ code
#include <linux/delay.h>
#include <linux/platform_device.h>
#include <linux/of_device.h>
#include <linux/sched.h>
#include <asm/siginfo.h>
#include <linux/pid_namespace.h>
#include <linux/pid.h>


#define  DEVICE_NAME "zed_io"      //< The device will appear at /dev/zed_io using this value
#define  CLASS_NAME  "zed"         //< The device class -- this is a character device driver
#define  C_ADDR_DEV 0x40000000     // device base address
#define  C_LED_OFST 0              // led offset 
#define  C_BUTT_SW_OFST 0x04       // button and switches offset
#define  C_BUTT_SW_INT_OFST 0x08   // button and switches interrupt status offset
#define  C_INT_SET_OFST 0x0C       // interrupt set
#define  C_INT_CLR_OFST 0x10       // interrupt clear
#define  C_INT_BUTT_EDGE_OFST 0x14 // interrupt button edge
#define  C_DEB_ENA_OFST 0x20       // debouncer ena
#define  C_DEB_TIME_OFST 0x24      // debounce time
#define  C_TEST_OFST 0x28          // test pattern
#define  C_INVOKE_INT_OFST 0x2C    // test pattern
#define  C_NUM_REG 9               // number of readable registers

/* Use '81' as magic number */
#define ZED_IO_MAGIC 81

#define SIGETX 44 // signal to user space 

#define ZED_IO_INT_SET       _IOW(ZED_IO_MAGIC, 1, int)
#define ZED_IO_INT_CLR       _IOW(ZED_IO_MAGIC, 2, int)
#define ZED_IO_INT_BUTT_EDGE _IOW(ZED_IO_MAGIC, 3, int)
#define ZED_IO_DEB_ENA       _IOW(ZED_IO_MAGIC, 4, int)
#define ZED_IO_DEB_TIM       _IOW(ZED_IO_MAGIC, 5, int)
#define ZED_IO_USER_SIG      _IOW(ZED_IO_MAGIC, 6, int)

MODULE_LICENSE("GPL");            ///< The license type -- this affects available functionality
MODULE_AUTHOR("Vladimir Beran");    ///< The author -- visible when you use modinfo
MODULE_DESCRIPTION("Zedboad IO Linux char driver");  ///< The description -- see modinfo
MODULE_VERSION("0.1");            ///< A version number to inform users

static int    majorNumber;                  ///< Stores the device number -- determined automatically
static int    numberOpens = 0;              ///< Counts the number of times the device is opened
static int    data[9] = {0};               ///< Memory for the data passed to user space
static int    rc = 0;
static struct class*  zed_ioClass  = NULL; ///< The device-driver class struct pointer
static struct device* zed_ioDevice = NULL; ///< The device-driver device struct pointer
void * virt;
static struct task_struct *task = NULL; // 
struct resource *res;

// The prototype functions for the character driver -- must come before the struct definition
static int send_sig_info(int sig, struct siginfo *info, struct task_struct *p);
static int     dev_open(struct inode *, struct file *);
static int     dev_release(struct inode *, struct file *);
static ssize_t dev_read(struct file *, char *, size_t, loff_t *);
static ssize_t dev_write(struct file *, const char *, size_t, loff_t *);
static long    dev_ioctl(struct file *, unsigned int, unsigned long);

/// Function prototype for the custom IRQ handler function -- see below for the implementation
static irq_handler_t  zed_io_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);

/** @brief Devices are represented as file structure in the kernel. The file_operations structure from
 *  /linux/fs.h lists the callback functions that you wish to associated with your file operations
 *  using a C99 syntax structure. char devices usually implement open, read, write and release calls
 */
static struct file_operations fops =
{
   .open = dev_open,
   .read = dev_read,
   .write = dev_write,
   .unlocked_ioctl = dev_ioctl,
   .release = dev_release,
};

// struct mydriver_dm
// {
//    void __iomem *    membase; // ioremapped kernel virtual address
//    dev_t             dev_num; // dynamically allocated device number
//    struct cdev       c_dev;   // character device
//    struct class *    class;   // sysfs class for this device
//    struct device *   pdev;    // device
//    int               irq; // the IRQ number ( note: this will NOT be the value from the DTS entry )
// };
// 
// static struct mydriver_dm dm;

static int mydriver_of_probe(struct platform_device *ofdev)
{
   int result;
   //int irq;
   //struct resource *res;

   res = platform_get_resource(ofdev, IORESOURCE_IRQ, 0);
   if (!res) {
      printk(KERN_INFO "could not get platform IRQ resource.\n");
      goto fail_irq;
   }

   // save the returned IRQ
   //dm.irq = res->start;

   printk(KERN_INFO "IRQ read form DTS entry as %d\n", res->start);
   // This next call requests an interrupt line
   result = request_irq(res->start,             // The interrupt number requested
                    (irq_handler_t) zed_io_irq_handler, // The pointer to the handler function below
                     IRQF_TRIGGER_HIGH,   // Interrupt on rising edge (button press, not release)
                     "zed_io_handler",    // Used in /proc/interrupts to identify the owner
                     NULL);                 // The *dev_id for shared interrupt lines, NULL is okay   
   printk(KERN_INFO "Zed_IO: The interrupt request result is: %d\n", result);
// 
   return 0;

fail_irq:
   return -1;

}

static int mydriver_of_remove(struct platform_device *of_dev)
{
    free_irq(res->start, NULL);
}

static const struct of_device_id mydriver_of_match[] = {
   { .compatible = "zlnx,zed_io", },
   { /* end of list */ },
};
MODULE_DEVICE_TABLE(of, mydriver_of_match);

static struct platform_driver mydrive_of_driver = {
   .probe      = mydriver_of_probe,
   .remove     = mydriver_of_remove,
   .driver = {
      .name = "zed_io",
      .owner = THIS_MODULE,
      .of_match_table = mydriver_of_match,
   },
};

/** @brief The LKM initialization function
 *  The static keyword restricts the visibility of the function to within this C file. The __init
 *  macro means that for a built-in driver (not a LKM) the function is only used at initialization
 *  time and that it can be discarded and its memory freed up after that point.
 *  @return returns 0 if successful
 */
static int __init zed_io_init(void){
   printk(KERN_INFO "Zed_IO : Initializing Zed IO Char LKM\n");

   // Try to dynamically allocate a major number for the device -- more difficult but worth it
   majorNumber = register_chrdev(0, DEVICE_NAME, &fops);
   if (majorNumber<0){
      printk(KERN_ALERT "Zed_IO failed to register a major number\n");
      return majorNumber;
   }
   printk(KERN_INFO "Zed_IO: registered correctly with major number %d\n", majorNumber);

   // Register the device class
   zed_ioClass = class_create(THIS_MODULE, CLASS_NAME);
   if (IS_ERR(zed_ioClass)){                // Check for error and clean up if there is
      unregister_chrdev(majorNumber, DEVICE_NAME);
      printk(KERN_ALERT "Failed to register device class\n");
      return PTR_ERR(zed_ioClass);          // Correct way to return an error on a pointer
   }
   printk(KERN_INFO "Zed_IO: device class registered correctly\n");

   // Register the device driver
   zed_ioDevice = device_create(zed_ioClass, NULL, MKDEV(majorNumber, 0), NULL, DEVICE_NAME);
   if (IS_ERR(zed_ioClass)){               // Clean up if there is an error
      class_destroy(zed_ioClass);           // Repeated code but the alternative is goto statements
      unregister_chrdev(majorNumber, DEVICE_NAME);
      printk(KERN_ALERT "Failed to create the device\n");
      return PTR_ERR(zed_ioDevice);
   }
   
   // request for acces to IO
   virt=ioremap_nocache(C_ADDR_DEV, 4096);
   
   platform_driver_register(&mydrive_of_driver);
   
   
   printk(KERN_INFO "Zed_IO: device class created correctly\n"); // Made it! device was initialized
   return 0;
}

/** @brief The LKM cleanup function
 *  Similar to the initialization function, it is static. The __exit macro notifies that if this
 *  code is used for a built-in driver (not a LKM) that this function is not required.
 */
static void __exit zed_io_exit(void){
   iounmap(virt);                                          // free memory 
   platform_driver_unregister(&mydrive_of_driver);
   device_destroy(zed_ioClass, MKDEV(majorNumber, 0));     // remove the device
   class_unregister(zed_ioClass);                          // unregister the device class
   class_destroy(zed_ioClass);                             // remove the device class
   unregister_chrdev(majorNumber, DEVICE_NAME);            // unregister the major number
   printk(KERN_INFO "Zed_IO: destroyed\n");
}

/** @brief The device open function that is called each time the device is opened
 *  This will only increment the numberOpens counter in this case.
 *  @param inodep A pointer to an inode object (defined in linux/fs.h)
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 */
static int dev_open(struct inode *inodep, struct file *filep){
   numberOpens++;
   return 0;
}

/** @brief This function is called whenever device is being read from user space i.e. data is
 *  being sent from the device to the user. In this case is uses the copy_to_user() function to
 *  send the buffer string to the user and captures any errors.
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 *  @param buffer The pointer to the buffer to which this function writes the data
 *  @param len The length of the b
 *  @param offset The offset if required
 */
static ssize_t dev_read(struct file *filep, char *buffer, size_t len, loff_t *offset){
   int error_count = 0;  
   if (len == 1) { // read button & switches
     data[0] = readl(virt+C_BUTT_SW_OFST);
     error_count = copy_to_user(buffer, data, len*4);
     return 1;
   } else if (len == 2) { // read button & switches and interrupt status
     data[0] = readl(virt+C_BUTT_SW_OFST);
     data[1] = readl(virt+C_BUTT_SW_INT_OFST);
     error_count = copy_to_user(buffer, data, len*4);
     return 1;
   } else if (len == 3) { // read led + button & switches and interrupt status
     data[0] = readl(virt+C_LED_OFST);
     data[1] = readl(virt+C_BUTT_SW_OFST);
     data[2] = readl(virt+C_BUTT_SW_INT_OFST);  
     error_count = copy_to_user(buffer, data, len*4);
     return 1;
   } else if (len == 9){ // read all 
     data[0] = readl(virt+C_LED_OFST);
     data[1] = readl(virt+C_BUTT_SW_OFST);
     data[2] = readl(virt+C_BUTT_SW_INT_OFST);
     data[3] = readl(virt+C_INT_SET_OFST); // interrupt set
     data[4] = readl(virt+C_INT_CLR_OFST); // interrupt clear
     data[5] = readl(virt+C_INT_BUTT_EDGE_OFST);
     data[6] = readl(virt+C_DEB_ENA_OFST);
     data[7] = readl(virt+C_DEB_TIME_OFST);
     data[8] = readl(virt+C_TEST_OFST);     
     error_count = copy_to_user(buffer, data, len*4);
     return 1;
   } else { // read nothing
     printk(KERN_INFO "Zed_IO: read bad lenght of buffer\n"); 
     return 0;
   }
   if (error_count != 0) {
     printk(KERN_INFO "Zed_IO: read fail\n"); 
     return 0;
   }
}

/** @brief This function is called whenever the device is being written to from user space i.e.
 *  data is sent to the device from the user. The data is copied to the message[] array in this
 *  LKM using the sprintf() function along with the length of the string.
 *  @param filep A pointer to a file object
 *  @param buffer The buffer to that contains the string to write to the device
 *  @param len The length of the array of data that is being passed in the const char buffer
 *  @param offset The offset if required
 */
static ssize_t dev_write(struct file *filep, const char *buffer, size_t len, loff_t *offset){ 
   int error_count = 0; 
   //unsigned long irqs;
   //int irq;
   //int i;
   //int result;
   if (len == 1) {
     error_count = copy_from_user(data, buffer ,len); 
     writeb(data[0], virt);
   }
   if (error_count != 0) {
     printk(KERN_INFO "Zed_IO: write fail\n");
   }

   return 1;
}

static long dev_ioctl(struct file *filep, unsigned int _cmd, unsigned long _arg) {  
    switch (_cmd)
    {
        case ZED_IO_INT_SET: // interrupt set
        {
          writel(_arg ,virt + C_INT_SET_OFST);
          wmb();            
          return 0;
        }
        case ZED_IO_INT_CLR: // interrupt clear
        {    
          writel(_arg ,virt + C_INT_CLR_OFST);  
          wmb();
          return 0;
        }
        case ZED_IO_INT_BUTT_EDGE: // button interrupt posedge set config
        {
          writel(_arg ,virt + C_INT_BUTT_EDGE_OFST);
          wmb();                
          return 0;
        }
        case ZED_IO_DEB_ENA: // debouncer ena 
        {       
          writel(_arg ,virt + C_DEB_ENA_OFST);
          wmb();
          return 0;
        } 
        case ZED_IO_DEB_TIM: // debouncer time
        {    
          writel(_arg ,virt + C_DEB_TIME_OFST);
          wmb();
          return 0;
        }  
        case ZED_IO_USER_SIG:
        {
          task = get_current();  
          return 0;
        }    
        default:
        {    
           printk(KERN_INFO "Zed_IO: undefined ioctl\n");
           return 1;
        }            
    }    
}

/** @brief The device release function that is called whenever the device is closed/released by
 *  the userspace program
 *  @param inodep A pointer to an inode object (defined in linux/fs.h)
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 */
static int dev_release(struct inode *inodep, struct file *filep){
   return 0;
}


/** @brief The GPIO IRQ Handler function
 *  This function is a custom interrupt handler that is attached to the GPIO above. The same interrupt
 *  handler cannot be invoked concurrently as the interrupt line is masked out until the function is complete.
 *  This function is static as it should not be invoked directly from outside of this file.
 *  @param irq    the IRQ number that is associated with the GPIO -- useful for logging.
 *  @param dev_id the *dev_id that is provided -- can be used to identify which device caused the interrupt
 *  Not used in this example as NULL is passed.
 *  @param regs   h/w specific register values -- only really ever used for debugging.
 *  return returns IRQ_HANDLED if successful -- should return IRQ_NONE otherwise.
 */
static irq_handler_t zed_io_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs){
   struct siginfo info;
   writel(0x00000fff ,virt + C_BUTT_SW_INT_OFST);  // clear all pending interrupt 
   
   // send signal to user space
 
   memset(&info, 0, sizeof(struct siginfo));
   info.si_signo = SIGETX;
   info.si_code = SI_QUEUE;
   info.si_int = 1;

   if (task != NULL) {
        if(send_sig_info(SIGETX, &info, task) < 0) {
            printk(KERN_INFO "Unable to send signal\n");
        }
    }      
   
   //printk(KERN_INFO "ZED_IO: Interrupt\n");
   //numberPresses++;                         // Global counter, will be outputted when the module is unloaded   
   return (irq_handler_t) IRQ_HANDLED;      // Announce that the IRQ has been handled correctly
}

/** @brief A module must use the module_init() module_exit() macros from linux/init.h, which
 *  identify the initialization function at insertion time and the cleanup function (as
 *  listed above)
 */
module_init(zed_io_init);
module_exit(zed_io_exit);
