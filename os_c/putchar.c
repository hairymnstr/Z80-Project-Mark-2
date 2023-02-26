__sfr __at 0x05 SCREEN_TX_BUFF;

void putchar(char c)
{
    SCREEN_TX_BUFF = c;
}
