module;

#include <stdio.h>
#ifdef _WIN32
#include <windows.h>
#endif

export module gotoxy;

export void gotoxy(short x, short y) {
#ifdef _WIN32
	static HANDLE h = NULL;
	if (!h)
		h = GetStdHandle(STD_OUTPUT_HANDLE);
	COORD c = {x, y};
	SetConsoleCursorPosition(h, c);
#else
	printf("\033[%d;%dH", y, x);
#endif
}
