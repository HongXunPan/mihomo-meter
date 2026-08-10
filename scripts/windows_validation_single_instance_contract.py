"""定义 Windows 跨安装形态单实例静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "platform" / "windows" / "MihomoMeter.Windows.App"
WINDOWS_WORKFLOW = ROOT / ".github" / "workflows" / "windows.yml"

SINGLE_INSTANCE_REQUIRED_REPOSITORY_FILES = (
    "scripts/windows_validation_single_instance_contract.py",
)

SINGLE_INSTANCE_REQUIRED_APP_FILES = (
    "Lifecycle/SingleInstanceCoordinator.cs",
)

SINGLE_INSTANCE_REQUIRED_CODE_MARKERS = {
    WINDOWS_WORKFLOW: (
        '"scripts/windows_validation_single_instance_contract.py"',
    ),
    APP_ROOT / "Program.cs": (
        "SingleInstanceCoordinator.CreateForCurrentSession",
        "instanceCoordinator.StartListening",
        "instanceCoordinator.RedirectActivationAsync",
        "ActivationRouter.RequestMainWindowActivation",
        "AllowSetForegroundWindow",
        "previousSynchronizationContext",
        "instanceCoordinator.DisposeAsync().ConfigureAwait(false)",
        'StartupConsoleReporter.Stage("single_instance_shutdown_completed")',
    ),
    APP_ROOT / "Lifecycle/SingleInstanceCoordinator.cs": (
        r"Local\com.HongXunPan.MihomoMeter.SingleInstance",
        "Process.GetCurrentProcess()",
        "currentProcess.SessionId",
        "NamedPipeServerStream",
        "NamedPipeClientStream",
        "PipeOptions.CurrentUserOnly",
        "ActivateMainWindowCommand",
    ),
}

SINGLE_INSTANCE_FORBIDDEN_CODE_MARKERS = (
    "FindOrRegisterForKey",
    "RedirectActivationToAsync",
    "await using var instanceCoordinator",
)
