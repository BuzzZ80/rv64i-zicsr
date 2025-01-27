#ifndef TOOLS_H
#define TOOLS_H

extern volatile unsigned long long int * const I_OUTPUT;
extern volatile char * const OUTPUT;

#define CSR_READ(v, csr)                       \
/* CSRR_READ(v, csr):
 * csr: MUST be a compile time integer 12-bit constant (0-4095)
 */                                             \
__asm__ __volatile__ ("csrr %0, %1"             \
              : "=r" (v)                        \
              : "n" (csr)                       \
              : /* clobbers: none */ )

#define CSR_WRITE(v, csr)                      \
/* CSRR_READ(v, csr):
 * csr: MUST be a compile time integer 12-bit constant (0-4095)
 */                                             \
__asm__ __volatile__ ("csrw %0, %1"             \
              :                                 \
              : "n" (csr),                      \
                "r" (v)                         \
              : /* clobbers: none */ )

#define CSR_SET(v, csr)                      \
/* CSRR_READ(v, csr):
 * csr: MUST be a compile time integer 12-bit constant (0-4095)
 */                                             \
__asm__ __volatile__ ("csrrs x0, %0, %1"        \
              :                                 \
              : "n" (csr),                      \
                "r" (v)                         \
              : /* clobbers: none */ )

#define CSR_CLEAR(v, csr)                      \
/* CSRR_READ(v, csr):
 * csr: MUST be a compile time integer 12-bit constant (0-4095)
 */                                             \
__asm__ __volatile__ ("csrrc x0, %0, %1"        \
              :                                 \
              : "n" (csr),                      \
                "r" (v)                         \
              : /* clobbers: none */ )

void prints(char *c);
void printx(int n);

//int mult32(int a, int b);
//int div32(int a, int b);
//int mod32(int a, int b);

#endif