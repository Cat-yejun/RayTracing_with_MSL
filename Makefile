# Variables
CXX = clang++
CXXFLAGS = -std=c++17 -Wall -Wextra -Werror -Iinclude
LDFLAGS = -framework Foundation -framework Metal -framework QuartzCore

# Source files
SRCS = src/main.mm
OBJS = $(SRCS:.mm=.o)

# Output file
EXEC = MyMetalProject

# Build rules
all: $(EXEC)

$(EXEC): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(EXEC) $(LDFLAGS)

src/%.o: src/%.mm
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean rules
clean:
	rm -f src/*.o $(EXEC)

.PHONY: all clean
