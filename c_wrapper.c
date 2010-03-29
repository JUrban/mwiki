#define REAL_PATH "/path/to/script"
main(ac, av)
char **av;
{
   execv(REAL_PATH, av);
}
