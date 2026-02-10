#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xil_printf.h"
#include "xaxidma.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "sleep.h" // usleep 사용을 위해 추가

// -----------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------
#define DMA_DEV_ID          XPAR_AXIDMA_0_DEVICE_ID
#define IMG_WIDTH           28
#define OUT_WIDTH           26
#define IMG_HEIGHT          10
#define TEST_DATA_LEN       (IMG_WIDTH * IMG_HEIGHT)

u8 TxBuffer[TEST_DATA_LEN];
int RxBuffer[TEST_DATA_LEN];
XAxiDma AxiDma;

int Init_DMA() {
    XAxiDma_Config *CfgPtr;
    int Status;

    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr) return XST_FAILURE;

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    return XST_SUCCESS;
}

int main()
{
    init_platform();
    int Status;

    xil_printf("\r\n=== CNN Visual Test (Force Mode) ===\r\n");

    if (Init_DMA() != XST_SUCCESS) {
        xil_printf("DMA Init Failed!\r\n");
        return -1;
    }

    // 1. Generate Input Image
    xil_printf("\r\n[1] Input Image Preview:\r\n");
    for(int row = 0; row < IMG_HEIGHT; row++) {
        for(int col = 0; col < IMG_WIDTH; col++) {
            int idx = row * IMG_WIDTH + col;
            if (col >= 10 && col < 20) {
                TxBuffer[idx] = 200;
                xil_printf("#");
            } else {
                TxBuffer[idx] = 10;
                xil_printf(".");
            }
        }
        xil_printf("\r\n");
    }

    // 2. Cache Flush
    Xil_DCacheFlushRange((UINTPTR)TxBuffer, TEST_DATA_LEN * sizeof(u8));
    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, TEST_DATA_LEN * sizeof(int));

    // 3. Start DMA Transfer
    // 길이를 넉넉하게 잡아도 됩니다. 어차피 TLAST가 없어서 시간으로 끊을 거니까요.
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBuffer,
            TEST_DATA_LEN * sizeof(int), XAXIDMA_DEVICE_TO_DMA);

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBuffer,
            TEST_DATA_LEN * sizeof(u8), XAXIDMA_DMA_TO_DEVICE);

    // -------------------------------------------------------------------
    // 4. Force Wait (Busy Check 제거!)
    // -------------------------------------------------------------------
    // DMA가 끝났는지 물어보지 않고, 그냥 1초 기다립니다.
    // 하드웨어 속도는 수 마이크로초 단위라 1초면 충분히 다 들어옵니다.
    xil_printf("Waiting for hardware... (1 sec)\r\n");
    sleep(1);

    // 5. Visualize Results
    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, TEST_DATA_LEN * sizeof(int));

    xil_printf("\r\n[2] Output Result (Edge Detection):\r\n");

    // 유효한 데이터가 있는지 먼저 스캔
    int valid_rows = IMG_HEIGHT - 2; // 8 rows


        // [수정 후] 위아래 1줄씩 더 떼고, 진짜 확실한 '중앙'만 봅니다.
        // row = 1부터 시작, row < valid_rows - 1 까지

        xil_printf("Printing Safe Zone (Skipping boundary artifacts)...\r\n");

        for(int row = 1; row < valid_rows - 1; row++) { // 첫 줄(0)과 막줄(끝) 제외
            for(int col = 0; col < OUT_WIDTH; col++) {

                int val = RxBuffer[row * OUT_WIDTH + col];
                int abs_val = (val < 0) ? -val : val;

                if (abs_val > 100) {
                    xil_printf("|");
                } else {
                    xil_printf(" ");
                }
            }
            xil_printf("\r\n");
        }

    cleanup_platform();
    return 0;
}
