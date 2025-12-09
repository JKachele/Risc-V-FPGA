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
#define CYCLE                   SOC__DOT__csr__DOT__CSR_cycle;
#define INSTRET                 SOC__DOT__csr__DOT__CSR_instret;

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
        IData nbMUL = 0;
        IData nbDIV = 0;

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
                if (riscV_isMul(rootp->MW_instr))
                        nbMUL++;
                if (riscV_isDiv(rootp->MW_instr))
                        nbDIV++;
                if (rootp->dataHazard == 1)
                        nbLoadHazard++;
        }

public:
        IData prevLEDS;

        virtual void tick(void) {
                TESTB<VSOC>::tick();
                if (prevLEDS != m_core->LEDS) {
                        printf("LEDS: ");
                        printf("%x - ", m_core->LEDS);
                        for (int i=0; i<16; i++) {
                                printf("%d", (m_core->LEDS >> (15-i)) & 1);
                        }
                        printf("\n");
                }
                prevLEDS = m_core->LEDS;
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

        void printStatusReport(void) {
                u64 cycle = rootp->CYCLE;
                u64 instret = rootp->INSTRET;

                printf("\n\nSimulated processor's report\n");
                printf("----------------------------\n");
                printf("Branch hit = %3.3f\%%\n", nbBranchHit*100.0/nbBranch);
                printf("JALR   hit = %3.3f\%%\n", nbJALRhit*100.0/nbJALR);
                printf("Load hzrds = %3.3f\%%\n", nbLoadHazard*100.0/nbLoad);
                printf("CPI        = %3.3f\n",(cycle*1.0)/(instret*1.0));
                printf("Instret    = %ld\n", instret);
                printf("Instr. mix = (");
                printf("Branch:%3.3f\%% | ",    nbBranch*100.0/instret);
                printf("JAL:%3.3f\%% | ",       nbJAL*100.0/instret);
                printf("JALR:%3.3f\%% | ",      nbJALR*100.0/instret);
                printf("Load:%3.3f\%% | ",      nbLoad*100.0/instret);
                printf("Store:%3.3f\%% | ",     nbStore*100.0/instret);
                printf("MUL(HSU):%3.3f\%% | ", nbMUL*100.0/instret);
                printf("DIV/REM:%3.3f\%%",   nbDIV*100.0/instret);
                printf(")\n");
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

        tb->opentrace("trace.vcd");

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
