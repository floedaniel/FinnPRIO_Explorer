# The colors used in the Plot and in the Tables are from the palette of Ruokavirasto (2022).
# Assign colors to each quarantine status for the plot:
cols_pal_quarantine <- c("Other quarantine"="#D0006F",
              "Priority"="#F7CE3C",
              "Protected zone" ="#6D9F80",
              "Emergency measures"= "#FF6F49",
              "RNQP"="#004F71",
              "Other non-quarantine"="#ADD2EE",
              "NA"="#CCCCCC")  # Gray color for missing quarantine status

# Keep cols_pal as alias for backwards compatibility
cols_pal <- cols_pal_quarantine

# Colors for taxonomic groups (names include EPPO codes)
cols_pal_taxonomic <- c(
  "Insects [1INSEC]" = "#E41A1C",                              # Red
  "Mites [1ACARO]" = "#FF7F00",                                # Orange
  "Nematodes [1NEMAP]" = "#984EA3",                            # Purple
  "Snails and slugs (Molluscs) [1MOLLP]" = "#A65628",          # Brown
  "Bacteria and phytoplasma [1BACTK]" = "#377EB8",             # Blue
  "Fungi and fungus-like organisms [1FUNGK or 1PSDFP]" = "#4DAF4A",  # Green
  "Viruses and viroids [1VIRUK]" = "#F781BF",                  # Pink
  "Invasive alien plants [1MAGP]" = "#228B22",                 # Forest green
  "NA" = "#CCCCCC"                                             # Gray for unknown
)

# Colors for presence in Europe
cols_pal_presence <- c(
  "Present" = "#E74C3C",   # Present - Red
  "Absent" = "#3498DB",    # Absent - Blue
  "Unknown" = "#CCCCCC"    # Unknown - Gray
)
