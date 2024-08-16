#ifndef INTERVAL_H
#define INTERVAL_H

#include "rtweekend.h"

class interval {
public:
    interval(double min, double max) : min_(min), max_(max) {}

    double min() const { return min_; }
    double max() const { return max_; }

    double clamp(double value) const {
        if (value < min_) return min_;
        if (value > max_) return max_;
        return value;
    }

private:
    double min_, max_;
};

#endif
