export interface DropdownItem {
  id: string;
  label: string;
}

@Component
export struct Dropdown {
  @Prop items: Array<DropdownItem> = [];
  @Link selectedId: string;
  @Link selectedLabel: string;
  @Prop isEnabled: boolean = true;

  @State expanded: boolean = false;

  private getSelectedLabel(): string {
    if (this.selectedLabel) {
      return this.selectedLabel;
    }
    const match = this.items.find((item) => item.id === this.selectedId);
    return match ? match.label : '';
  }

  build() {
    Column() {
      Row() {
        Text(this.getSelectedLabel() || 'Select')
          .fontSize(14)
          .fontColor(this.isEnabled ? 0xFF222222 : 0xFF8A8A8A);
        Text(this.expanded ? '▲' : '▼')
          .fontSize(12)
          .fontColor(0xFF8A8A8A);
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')
      .padding(12)
      .border({ width: 1, color: 0xFFE0E0E0 })
      .borderRadius(8)
      .backgroundColor(0xFFF7F7F7)
      .onClick(() => {
        if (this.isEnabled) {
          console.error(`[WidgetDropdown] toggle expanded=${this.expanded} items=${this.items.length}`);
          this.expanded = !this.expanded;
        }
      });

      if (this.expanded) {
        Column() {
          ForEach(
            this.items,
            (item: DropdownItem) => {
              Row() {
                Text(item.label)
                  .fontSize(14)
                  .fontColor(item.id === this.selectedId ? 0xFF1E88E5 : 0xFF222222);
                if (item.id === this.selectedId) {
                  Text('✓')
                    .fontSize(14)
                    .fontColor(0xFF1E88E5);
                }
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                console.error(`[WidgetDropdown] select id=${item.id} label=${item.label}`);
                this.selectedId = item.id;
                this.selectedLabel = item.label;
                this.expanded = false;
              });
            },
            (item: DropdownItem) => item.id,
          );
        }
        .width('100%')
        .border({ width: 1, color: 0xFFE0E0E0 })
        .borderRadius(8)
        .backgroundColor(0xFFFFFFFF);
      }
    }
  }
}
