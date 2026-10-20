// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// One in-flight read; accelerate on visible window or recent target mouse input.
namespace RazerBatteryTray
{
    public sealed class ActivityRefreshSchedule
    {
        private bool busy, started;
        private long lastStarted;
        private readonly object gate = new object();
        public bool TryBegin(long nowMilliseconds, bool visible, bool active)
        {
            lock (gate)
            {
                if (busy || (started && nowMilliseconds - lastStarted < (visible || active ? 1000 : 5000))) return false;
                busy = true; started = true; lastStarted = nowMilliseconds; return true;
            }
        }
        public void Complete() { lock (gate) busy = false; }
    }
}
