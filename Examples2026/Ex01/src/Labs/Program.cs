using System.Runtime.CompilerServices;
using Labs.Utils;

namespace Labs
{
    public class Program
    {

        public static void Main(string[] args)
        {
            Dictionary<string, string?> parameters = CmdArgsParser.Parse(args);

            Console.WriteLine("Parameters:");
            foreach(KeyValuePair<string, string?> param in parameters)
            {
                Console.WriteLine("{0}: {1}", param.Key, param.Value);
            }
            
            if (args.Length == 0)
            {
                Console.WriteLine("HELP:");
                Console.WriteLine("    --task - task number");
                Console.WriteLine("    -x - value of X");
                Console.WriteLine("    -y - value of Y");
                Console.WriteLine("    -z - value of Z");
            }

            int iTask = int.Parse(parameters["--task"]);
            if (iTask == 1)
            {
                Console.WriteLine("Calculator will here");
            }
            else
            {
                Console.WriteLine("ERROR: Task {0} not found.", iTask);
            }
        }
    }
}