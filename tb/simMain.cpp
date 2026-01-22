#include <stdio.h>
#include "VSOC.h"
#include "VSOC___024root.h"
#include "testbench.h"
#include "uartsim.h"
#include "riscVDis.h"

#define HALT                    SOC__DOT__CPU__DOT__HALT
#define D_stall                 SOC__DOT__CPU__DOT__D_stall
#define dataHazard              SOC__DOT__CPU__DOT__dataHazard
#define DE_instr                SOC__DOT__CPU__DOT__DE_instr
#define E_takeBranch            SOC__DOT__CPU__DOT__E_takeBranch
#define DE_predictBranch        SOC__DOT__CPU__DOT__DE_predictBranch
#define DE_predictRA            SOC__DOT__CPU__DOT__DE_predictRA
#define E_JALRaddr              SOC__DOT__CPU__DOT__execute__DOT__E_JALRaddr
#define MW_instr                SOC__DOT__CPU__DOT__MW_instr
#define CYCLE                   SOC__DOT__CPU__DOT__csr__DOT__CSR_cycle;
#define INSTRET                 SOC__DOT__CPU__DOT__csr__DOT__CSR_instret;

class SOC_TB : public TESTB<VSOC> {
        // Statistics counters
        IData nbBranch = 0;
        IData nbBranchHit = 0;
        IData nbJAL  = 0;
        IData nbJALR = 0;
        IData nbJALRhit = 0;
        IData nbLoad = 0;
        IData nbStore = 0;
        IData nbLoadHazard = 0;
        IData nbRV32M = 0;
        IData nbMULDIV = 0;
        IData nbFPU = 0;
        IData nbAMO = 0;

        void updateStats(void) {
                if (m_core->RESET == 0 && rootp->D_stall == 0) {
                        if (riscV_isBranch(rootp->DE_instr)) {
                                nbBranch++;
                                if (rootp->E_takeBranch ==
                                                rootp->DE_predictBranch) {
                                        nbBranchHit++;
                                }
                        }
                        if (riscV_isJAL(rootp->DE_instr)) {
                                nbJAL++;
                        }
                        if (riscV_isJALR(rootp->DE_instr)) {
                                nbJALR++;
                                if (rootp->DE_predictRA == rootp->E_JALRaddr) {
                                        nbJALRhit++;
                                }
                        }
                }
                if (riscV_isLoad(rootp->MW_instr))
                        nbLoad++;
                if (riscV_isStore(rootp->MW_instr))
                        nbStore++;
                if (riscV_isMul(rootp->MW_instr) || riscV_isDiv(rootp->MW_instr))
                        nbMULDIV++;
                if (riscV_isFPU(rootp->MW_instr))
                        nbFPU++;
                if (riscV_isAMO(rootp->MW_instr))
                        nbAMO++;
                if (rootp->dataHazard == 1)
                        nbLoadHazard++;
        }

public:
        IData prevLEDS;
        CData prevCLK;

        virtual void tick(void) {
                TESTB<VSOC>::tick();
                CData clk = m_core->rootp->SOC__DOT__clk;
                // if (prevCLK != clk && clk == 1) {
                //         printf("%4x: ", m_core->rootp->SOC__DOT__CPU__DOT__FD_PC);
                //         printf("%x\n", m_core->rootp->SOC__DOT__CPU__DOT__FD_instr);
                //         printf("\tPriv: %x ", m_core->rootp->SOC__DOT__CPU__DOT__decode__DOT__DD_privilege);
                //         printf("MEPC: %x\n", m_core->rootp->SOC__DOT__CPU__DOT__csr__DOT__CSR_mepc);
                // }
                // if (prevLEDS != m_core->LEDS) {
                //         printf("LEDS: ");
                //         printf("%x - ", m_core->LEDS);
                //         for (int i=0; i<16; i++) {
                //                 printf("%d", (m_core->LEDS >> (15-i)) & 1);
                //         }
                //         printf("\n");
                // }
                prevLEDS = m_core->LEDS;
                prevCLK = m_core->rootp->SOC__DOT__clk;
                updateStats();
        }

        virtual bool done(void) {
                static int clocksAfterHalt = 0;
                if (rootp->HALT == 1)
                        clocksAfterHalt++;

                // Exit 1 clock after halt to allow simulation to finish
                if (clocksAfterHalt > 1)
                        return true;

                // Default
                return TESTB<VSOC>::done();
        }

        void printFReg(const char *name, QData reg) {
                double d = *(double*)&reg;
                float  f = *(float*)&reg;
                printf("%s: %lx (%0.16f) (%f)\n", name, reg, d, f);
        }

        void printIReg(const char *name, IData reg) {
                printf("%s: %x (%d)\n", name, reg, reg);
        }

        void printFRegisters(void) {
                printFReg("ft0",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F0);
                printFReg("ft1",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F1);
                printFReg("ft2",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F2);
                printFReg("ft3",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F3);
                printFReg("ft4",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F4);
                printFReg("ft5",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F5);
                printFReg("ft6",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F6);
                printFReg("ft7",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F7);
                // printFReg("fs0",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F8);
                // printFReg("fs1",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F9);
                // printFReg("fa0",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F10);
                // printFReg("fa1",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F11);
                // printFReg("fa2",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F12);
                // printFReg("fa3",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F13);
                // printFReg("fa4",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F14);
                // printFReg("fa5",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F15);
                // printFReg("fa6",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F16);
                // printFReg("fa7",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F17);
                // printFReg("fs2",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F18);
                // printFReg("fs3",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F19);
                // printFReg("fs4",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F20);
                // printFReg("fs5",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F21);
                // printFReg("fs6",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F22);
                // printFReg("fs7",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F23);
                // printFReg("fs8",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F24);
                // printFReg("fs9",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F25);
                // printFReg("fs10", m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F26);
                // printFReg("fs11", m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F27);
                // printFReg("ft8",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F28);
                // printFReg("ft9",  m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F29);
                // printFReg("ft10", m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F30);
                // printFReg("ft11", m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_F31);

                printIReg("x6" , m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_6);
                printIReg("x7" , m_core->rootp->SOC__DOT__CPU__DOT__registers__DOT__reg_7);
        }

        void printStatusReport(void) {
                u64 cycle = rootp->CYCLE;
                u64 instret = rootp->INSTRET;

                printf("\n\nSimulated processor's report\n");
                printf("----------------------------\n");
                printf("Branch hit = %3.3f\%%\n", nbBranchHit*100.0/nbBranch);
                printf("JALR   hit = %3.3f\%%\n", nbJALRhit*100.0/nbJALR);
                printf("Load hzrds = %3.3f\%%\n", nbLoadHazard*100.0/nbLoad);
                printf("Cycles     = %ld\n", cycle);
                printf("Instret    = %ld\n", instret);
                printf("CPI        = %3.3f\n",(cycle*1.0)/(instret*1.0));

                printf("Instr. mix = (");
                printf("Branch:%3.3f\%% | ",            nbBranch*100.0/instret);
                printf("JAL:%3.3f\%% | ",               nbJAL*100.0/instret);
                printf("JALR:%3.3f\%% | ",              nbJALR*100.0/instret);
                printf("Load:%3.3f\%% | ",              nbLoad*100.0/instret);
                printf("Store:%3.3f\%% | ",             nbStore*100.0/instret);
                printf("MUL/DIV/REM:%3.3f\%% | ",       nbMULDIV*100.0/instret);
                printf("FPU:%3.3f\%% | ",               nbFPU*100.0/instret);
                printf("AMO:%3.3f\%%",                  nbAMO*100.0/instret);
                printf(")\n");
                // printFRegisters();
        }

};

int main(int argc, char **argv) {
        // Initialize Verilators variables
        Verilated::commandArgs(argc, argv);

        // Create an instance of our module under test
        SOC_TB *tb = new SOC_TB();

        UARTSIM *uart;
        int port = 0;
        unsigned setup = 868;
        unsigned clocks = 0;
        unsigned baudclocks;

        uart = new UARTSIM(port);
        uart->setup(setup);
        baudclocks = setup & 0xfffffff;

        // tb->opentrace("trace.vcd");

        int rxPrev = 1;
        while (!tb->done()) {
                tb->tick();
                // tb->m_core->RXD = (*uart)(tb->m_core->TXD);
                // clocks++;
        }
        tb->printStatusReport();

        delete tb;
        return 0;
}
