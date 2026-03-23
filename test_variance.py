import torch
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from cortical_mgd.architecture.visual_hierarchy import VisualHierarchy

def main():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Device: {device}")

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
    ])
    train_ds = datasets.CIFAR100(root='./data', train=True, download=True, transform=transform)
    train_loader = DataLoader(train_ds, batch_size=256, shuffle=True, num_workers=4)

    vh = VisualHierarchy().to(device)
    vh.eval()

    # Get one batch untrained
    X_raw, y = next(iter(train_loader))
    X_b = X_raw.to(device)
    X_min = X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)
    X_max = X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1)
    X_01 = (X_b - X_min) / (X_max - X_min + 1e-8)

    features = vh(X_01).float()
    print("Features shape:", features.shape)
    
    unique_rows = torch.unique(features, dim=0)
    print("Unique feature vectors before training:", unique_rows.shape[0], "in a batch of", len(features))
    
    # Pretrain 1 batch
    vh.train()
    vh.stdp_update_all(X_01)
    
    vh.eval()
    features_trained = vh(X_01).float()
    unique_rows_trained = torch.unique(features_trained, dim=0)
    print("Unique feature vectors after 1 STDP update:", unique_rows_trained.shape[0])

    # Check how many neurons are dead across the whole batch
    active_neurons = (features_trained.sum(dim=0) > 0).sum().item()
    print("Active neurons across batch:", active_neurons, "out of", features_trained.shape[1])
    
    print("\nFeatures snapshot (first 5 images, first 20 neurons):")
    print(features_trained[:5, :20])

if __name__ == '__main__':
    main()
