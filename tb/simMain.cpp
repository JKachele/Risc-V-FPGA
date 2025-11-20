#include <stdio.h>
#include "VSOC.h"
#include "VSOC___024root.h"
#include "testbench.h"
#include "uartsim.h"

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
                static int clocksAfterHalt = 0;
                if (m_core->rootp->SOC__DOT__CPU__DOT__HALT == 1)
                        clocksAfterHalt++;

                // Exit 1 clock after halt to allow simulation to finish
                if (clocksAfterHalt > 1)
                        return true;

                // Default
                return TESTB<VSOC>::done();
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
                tb->m_core->RXD = (*uart)(tb->m_core->TXD);
                clocks++;
        }
        delete tb;
        return 0;
}
