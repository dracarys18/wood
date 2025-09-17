# Wood

A Zig implementation of [HyperLogLog](https://en.wikipedia.org/wiki/HyperLogLog), a probabilistic data structure for estimating the number of distinct elements in a multiset.

## Accuracy

- Memory usage = `2^p` registers  
- Standard error ≈ **1.04 / √(2^p)**  

| Precision (`p`) | Buckets (`m = 2^p`) | Expected Error |
|-----------------|---------------------|----------------|
| 10              | 1,024               | ~3.2%          |
| 12              | 4,096               | ~1.6%          |
| 14              | 16,384              | ~0.8%          |
| 16              | 65,536              | ~0.4%          |

