#include <stdio.h>
#include "VSOC.h"
#include "testbench.h"

class SOC_TB : public TESTB<VSOC> {
public:
        IData prevLEDS;

        virtual void tick(void) {
                TESTB<VSOC>::tick();
                if (prevLEDS != m_core->LEDS) {
                        printf("LEDS: ");
                        for (int i=0; i<16; i++) {
                                printf("%d", (m_core->LEDS >> (15-i)) & 1);
                        }
                        printf("\n");
                }
                prevLEDS = m_core->LEDS;
        }

        virtual bool done(void) {
                if (m_core->LEDS == 0xFFFF)
                        return true;
                else
                        return TESTB<VSOC>::done();
        }
};

int main(int argc, char **argv) {
        // Initialize Verilators variables
        Verilated::commandArgs(argc, argv);

        // Create an instance of our module under test
        SOC_TB *tb = new SOC_TB();
        // tb->opentrace("trace.vcd");

        while (!tb->done()) {
                tb->tick();
        }
        delete tb;
        return 0;
}
