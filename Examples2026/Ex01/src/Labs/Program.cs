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

            try
            {
                int iTask = int.Parse(parameters["--task"]);

                if (int.TryParse(parameters["--task"], out int iTask1))
                {
                    
                }
                
                if (iTask == 1)
                {
                    Console.WriteLine("Calculator will here");
                }
                else
                {
                    Console.WriteLine("ERROR: Task {0} not found.", iTask);
                }
            } 
            catch (Exception ex)
            {
                Console.WriteLine("ERROR: Value {0} is not integer", parameters["--task"]);
            }

            void foo(int val)
            {
                if (val == 0)
                {
                    Console.WriteLine("Нельзя делить на 0");
                    return;
                }
                if (val < 0)
                {
                    Console.WriteLine("Val должен быть больше 0");
                    return;
                }
                //...
                
            }
        }
    }
}