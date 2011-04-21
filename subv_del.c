#include <unistd.h>
#include <stdio.h>


int main (int argc, char *argv[])
{
  if (argc == 2)
    {
      execl ("/sbin/btrfs", "btrfs","subvolume", "delete", argv[1], (char *)0);
    }
  else
    {
      printf("Wrong number of arguments: %d.\n", argc);
      return 1;
    }
  return 0;
}

