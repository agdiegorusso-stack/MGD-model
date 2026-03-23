import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from cortical_mgd.architecture.visual_hierarchy import VisualHierarchy
import time

def main():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Device: {device}")

    # Load CIFAR-100
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
    ])
    train_ds = datasets.CIFAR100(root='./data', train=True, download=True, transform=transform)
    test_ds = datasets.CIFAR100(root='./data', train=False, download=True, transform=transform)

    train_loader = DataLoader(train_ds, batch_size=256, shuffle=True, num_workers=4)
    test_loader = DataLoader(test_ds, batch_size=256, shuffle=False, num_workers=4)

    # Initialize Visual Hierarchy
    vh = VisualHierarchy().to(device)
    
    # Pretrain the Visual Hierarchy briefly (1 epoch)
    print("Pretraining NeuromorphicVisualCortex (1 epoch)...")
    vh.train()
    t0 = time.time()
    for batch_idx, (X_raw, _) in enumerate(train_loader):
        X_b = X_raw.to(device)
        X_min = X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)
        X_max = X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1)
        X_01 = (X_b - X_min) / (X_max - X_min + 1e-8)
        
        vh.stdp_update_all(X_01)
        if batch_idx % 50 == 0:
            print(f"  Batch {batch_idx}/{len(train_loader)}")
    print(f"Pretraining done in {time.time() - t0:.1f}s")

    # Freeze VH
    vh.eval()
    for p in vh.parameters():
        p.requires_grad = False

    # Linear Probe
    probe = nn.Linear(VisualHierarchy.VH_OUT_DIM, 100).to(device)
    optimizer = torch.optim.Adam(probe.parameters(), lr=0.01)
    criterion = nn.CrossEntropyLoss()

    print("\nTraining Linear Probe (10 Epochs)...")
    epochs = 10
    target_acc = 1.0 # Goal set by user
    for ep in range(epochs):
        probe.train()
        correct = 0
        total = 0
        loss_sum = 0
        
        for X_raw, y in train_loader:
            X_b = X_raw.to(device)
            y = y.to(device)
            
            X_min = X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)
            X_max = X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1)
            X_01 = (X_b - X_min) / (X_max - X_min + 1e-8)
            
            with torch.no_grad():
                vh.reset_state()
                features = vh(X_01).float()  # 1024-dim spikes
                
            optimizer.zero_grad()
            logits = probe(features)
            loss = criterion(logits, y)
            loss.backward()
            optimizer.step()
            
            loss_sum += loss.item()
            pred = logits.argmax(dim=1)
            correct += (pred == y).sum().item()
            total += y.size(0)
            
        train_acc = correct / total
        
        # Test
        probe.eval()
        correct_t = 0
        total_t = 0
        with torch.no_grad():
            for X_raw, y in test_loader:
                X_b = X_raw.to(device)
                y = y.to(device)
                X_min = X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)
                X_max = X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1)
                X_01 = (X_b - X_min) / (X_max - X_min + 1e-8)
                
                vh.reset_state()
                features = vh(X_01).float()
                logits = probe(features)
                pred = logits.argmax(dim=1)
                correct_t += (pred == y).sum().item()
                total_t += y.size(0)
                
        test_acc = correct_t / total_t
        print(f"Epoch {ep+1}/{epochs} - Train Loss: {loss_sum/len(train_loader):.4f} - Train ACC: {train_acc:.4f} - Test ACC: {test_acc:.4f}")

if __name__ == '__main__':
    main()
