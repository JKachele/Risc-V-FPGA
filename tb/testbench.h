#include <verilated_vcd_c.h>

template<class MODULE> class TESTB {
public:
        VerilatedVcdC *m_trace;
        unsigned long m_tickcount;
        MODULE *m_core;

        TESTB(void) {
                m_core = new MODULE();
                Verilated::traceEverOn(true);
                m_tickcount = 01;
                m_core->CLK = 0;
                m_core->eval();
        }

        virtual ~TESTB(void) {
                closetrace();
                delete m_core;
                m_core = NULL;
        }

        virtual void opentrace(const char *vcdname) {
                if (!m_trace) {
                        m_trace = new VerilatedVcdC;
                        m_core->trace(m_trace, 99);
                        m_trace->open(vcdname);
                }
        }

        virtual void closetrace(void) {
                if (m_trace) {
                        m_trace->close();
                        m_trace = NULL;
                }
        }

        virtual void reset(void) {
                m_core->RESET = 1;
                this->tick();
                m_core->RESET = 0;
        }

        virtual void tick(void) {
                m_tickcount++;

                // Settle combinatorial logic before Ccock tick
                m_core->eval();

                // Dump values into trace file
                if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount-2));

                // Toggle Clock
                m_core->CLK = 1;
                m_core->eval();
                if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount));

                m_core->CLK = 0;
                m_core->eval();
                if (m_trace) {
                        m_trace->dump((vluint64_t)(10*m_tickcount+5));
                        m_trace->flush();
                }
        }

        virtual bool done(void) {
                return (Verilated::gotFinish());
        }
};
