// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Captured Metapanda Report 08 codec. C# 5 / .NET 4; never synthesizes unknown state.
using System;
namespace RazerBatteryTray
{
    public static class MetapandaProtocol
    {
        public static byte[] BuildCommand(byte command)
        {
            byte[] report = new byte[17]; report[0] = 8; report[1] = command; Finish(report); return report;
        }
        private static void Finish(byte[] report)
        {
            int sum = 0; for (int i = 0; i < 16; i++) sum += report[i]; report[16] = unchecked((byte)(0x55 - sum));
        }
        public static bool IsValid(byte[] report)
        {
            if (report == null || report.Length != 17 || report[0] != 8) return false;
            int sum = 0; for (int i = 0; i < 17; i++) sum += report[i]; return (sum & 255) == 0x55;
        }
        private static byte[] BuildSetting(int address, int value)
        {
            byte[] report = BuildCommand(7); report[4] = (byte)address; report[5] = 2;
            report[6] = (byte)value; report[7] = unchecked((byte)(0x55 - value)); Finish(report); return report;
        }
        public static byte[] BuildDpiStage(int oneBasedStage)
        {
            return oneBasedStage >= 1 && oneBasedStage <= 8 ? BuildSetting(4, oneBasedStage - 1) : null;
        }
        public static byte[] BuildPollingRate(int hz)
        {
            int code = hz == 125 ? 8 : hz == 250 ? 4 : hz == 500 ? 2 : hz == 1000 ? 1 : hz == 2000 ? 16 : hz == 4000 ? 32 : 0;
            return code == 0 ? null : BuildSetting(0, code);
        }
        public static byte[] BuildReadMemory(int address, int count)
        {
            if (address < 0 || address > 65535 || count < 1 || count > 10) return null;
            byte[] report = BuildCommand(8); report[3] = (byte)(address >> 8); report[4] = (byte)address;
            report[5] = (byte)count; Finish(report); return report;
        }
        public static bool MatchesResponse(byte[] request, byte[] response)
        {
            if (!IsValid(request) || !IsValid(response) || request[1] != response[1]) return false;
            if (request[1] == 7)
            {
                for (int i = 2; i < 16; i++) if (request[i] != response[i]) return false;
            }
            if (request[1] == 8)
            {
                for (int i = 2; i <= 5; i++) if (request[i] != response[i]) return false;
            }
            return true;
        }
        public static bool CopyMemoryResponse(byte[] request, byte[] response, byte[] memory)
        {
            if (!MatchesResponse(request, response) || request[1] != 8 || request[5] < 1 || request[5] > 10) return false;
            int address = request[3] * 256 + request[4];
            if (memory == null || address + request[5] > memory.Length) return false;
            Array.Copy(response, 6, memory, address, request[5]); return true;
        }
        public static bool DecodeBattery(byte[] response, out int percent, out bool charging)
        {
            percent = -1; charging = false;
            if (!IsValid(response) || response[1] != 4 || response[5] != 2 || response[6] > 100 || response[7] > 1) return false;
            percent = response[6]; charging = response[7] == 1; return true;
        }
        private static bool ValidBlock(byte[] memory, int offset, int count)
        {
            if (offset + count > memory.Length) return false;
            int sum = 0; for (int i = offset; i < offset + count; i++) sum += memory[i]; return (sum & 255) == 0x55;
        }
        public static bool DecodeSettings(byte[] memory, MouseBatteryInfo state)
        {
            // Official 3395 configuration is 50 DPI per encoded step; two-stage captured
            // table: 0f 0f 00 37 (800/800), 1f 1f 00 17 (1600/1600).
            // Nonzero extension bytes have no verified decoding; fail closed.
            if (memory == null || state == null || memory.Length < 12 || !ValidBlock(memory, 0, 2) ||
                !ValidBlock(memory, 4, 2) || !ValidBlock(memory, 10, 2)) return false;
            int count = memory[10] + 1; int stage = memory[4];
            if (count < 1 || count > 8 || stage >= count || memory.Length < 12 + count * 4) return false;
            int[] xs = new int[count]; int[] ys = new int[count];
            for (int i = 0; i < count; i++)
            {
                int p = 12 + i * 4; if (!ValidBlock(memory, p, 4) || memory[p + 2] != 0) return false;
                xs[i] = (memory[p] + 1) * 50;
                ys[i] = (memory[p + 1] + 1) * 50;
                if (xs[i] > 26000 || ys[i] > 26000) return false;
            }
            state.DpiStages = xs; state.DpiStagesY = ys; state.DpiStageCount = count; state.DpiStage = stage + 1;
            state.Dpi = xs[stage]; state.DpiY = ys[stage]; state.IsXyIndependent = state.Dpi != state.DpiY;
            state.PollingRate = memory[0] == 1 ? 1000 : memory[0] == 2 ? 500 : memory[0] == 4 ? 250 : memory[0] == 8 ? 125 : memory[0] == 16 ? 2000 : memory[0] == 32 ? 4000 : 0;
            return true;
        }
    }
}
