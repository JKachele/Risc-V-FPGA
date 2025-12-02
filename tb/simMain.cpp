#include <stdio.h>
#include "VSOC.h"
#include "VSOC___024root.h"
#include "testbench.h"
#include "uartsim.h"

#define nbBranch     tb->m_core->rootp->SOC__DOT__CPU__DOT__nbBranch
#define nbBranchHit  tb->m_core->rootp->SOC__DOT__CPU__DOT__nbBranchHit
#define nbJAL        tb->m_core->rootp->SOC__DOT__CPU__DOT__nbJAL
#define nbJALR       tb->m_core->rootp->SOC__DOT__CPU__DOT__nbJALR
#define nbJALRhit    tb->m_core->rootp->SOC__DOT__CPU__DOT__nbJALRhit
#define nbLoad       tb->m_core->rootp->SOC__DOT__CPU__DOT__nbLoad
#define nbStore      tb->m_core->rootp->SOC__DOT__CPU__DOT__nbStore
#define nbLoadHazard tb->m_core->rootp->SOC__DOT__CPU__DOT__nbLoadHazard
#define nbMUL        tb->m_core->rootp->SOC__DOT__CPU__DOT__nbMUL
#define nbDIV        tb->m_core->rootp->SOC__DOT__CPU__DOT__nbDIV
#define cycle        tb->m_core->rootp->SOC__DOT__csr__DOT__CSR_cycle
#define instret      tb->m_core->rootp->SOC__DOT__csr__DOT__CSR_instret

class SOC_TB : public TESTB<VSOC> {
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
        }

        virtual bool done(void) {
                // static int clocksAfterHalt = 0;
                // if (m_core->rootp->SOC__DOT__CPU__DOT__HALT == 1)
                //         clocksAfterHalt++;
                //
                // // Exit 1 clock after halt to allow simulation to finish
                // if (clocksAfterHalt > 1)
                //         return true;

                // Default
                return TESTB<VSOC>::done();
        }
};

// void printStatusReport(SOC_TB *tb) {
//         printf("\n\nSimulated processor's report\n");
//         printf("----------------------------\n");
//         printf("Branch hit = %3.3f\%%\n", nbBranchHit*100.0/nbBranch);
//         printf("JALR   hit = %3.3f\%%\n", nbJALRhit*100.0/nbJALR);
//         printf("Load hzrds = %3.3f\%%\n", nbLoadHazard*100.0/nbLoad);
//         printf("CPI        = %3.3f\n",(cycle*1.0)/(instret*1.0));
//         printf("Instr. mix = (");
//         printf("Branch:%3.3f\%%",    nbBranch*100.0/instret);
//         printf(" JAL:%3.3f\%%",       nbJAL*100.0/instret);
//         printf(" JALR:%3.3f\%%",      nbJALR*100.0/instret);
//         printf(" Load:%3.3f\%%",      nbLoad*100.0/instret);
//         printf(" Store:%3.3f\%%",     nbStore*100.0/instret);
//         printf(" MUL(HSU):%3.3f\%% ", nbMUL*100.0/instret);
//         printf(" DIV/REM:%3.3f\%% ",   nbDIV*100.0/instret);
//         printf(")\n");
// }

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
        // printStatusReport(tb);

        delete tb;
        return 0;
}
