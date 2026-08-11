using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class QuotaTrendDetailView : UserControl
{
    internal QuotaTrendDetailView(SubscriptionQuotaCardViewModel model)
    {
        Model = model;
        InitializeComponent();
    }

    public SubscriptionQuotaCardViewModel Model { get; }
}
