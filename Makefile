CC      = clang
FWORKS  = -framework Cocoa -framework ImageIO -framework QuartzCore
CFLAGS  = -fobjc-arc -O2 -Wall $(FWORKS)
SRCS    = main.m AppDelegate.m SpriteSheet.m BacteriaApp.m \
          InputPanel.m ChatBubble.m ClaudeClient.m
TARGET  = bacteria_app

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRCS)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)
