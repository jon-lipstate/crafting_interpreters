using System;

namespace csLox
{
    public static class Lox
    {
        static bool hadError = false;

        public static void Main(string[] args)
        {
            if (args.Length > 1)
            {
                Console.WriteLine("Usage: csLox [script]");
                Environment.Exit((int)SysExits.EX_USAGE);
            } else if (args.Length == 1) {
                runFile(args[0]);
            } else
            {
                runPrompt();
            }
        }
        public static void runFile(string path){
            byte[] bytes = File.ReadAllBytes(path);
            var str = System.BitConverter.ToString(bytes);
            run(str);

            if (hadError) {
                Environment.Exit((int)SysExits.EX_DATAERR);
            }
        }
        public static void runPrompt()
        {
            while (true)
            {
                Console.Write("> ");
                var line = Console.ReadLine();
                if (String.IsNullOrEmpty(line)) {
                    break;
                }
                run(line);
                hadError = false;
            }
        }
        public static void run(string src)
        {
            var scanner = new Scanner(src);
            List<Token> tokens = scanner.scanTokens();
            foreach(var token in tokens)
            {
                Console.WriteLine(token);
            }
        }
        public static void error(int line,string msg)
        {
            report(line, "", msg);
        }
        public static void report(int line,string where, string msg)
        {
            Console.Error.WriteLine($"[Line {line}] Error: {where} - {msg}");
            
        }

    }

    
}