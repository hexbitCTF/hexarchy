# System sleep

Hexarchy enables suspend and hibernation by default, but if you're having issues with either on your machine, you can toggle them off.

### Power profiles

On a laptop, Hexarchy remembers your power profile separately for plugged in and running on battery, and switches between the two as you plug and unplug. Out of the box that means performance on AC and balanced on battery.

You can see what your machine offers with `hexarchy powerprofiles list`, and set the one you want for the state you're currently in with `hexarchy powerprofiles set autodetect power-saver`. To set the other state without unplugging anything, name it directly: `hexarchy powerprofiles set battery power-saver`. Whatever you pick is what you'll get back the next time you're in that state.

### Toggle suspend

You toggle suspend by running `hexarchy toggle suspend` from the terminal. That just reveals/hides the option under _System_ (or `Super + Esc`), and then you can see if it works consistently on your system. If not, you can hide it again with the same command.

### Toggle hibernation

You set up hibernation by running `hexarchy hibernation setup` from the terminal. Hibernation creates a /swap subvolume on your boot drive the size of your physical RAM allocation, so make sure you have plenty of room to spare. On a 32GB machine, you'll always need 32GB+ free for this volume. Hibernation also requires the default Limine bootloader.

When set up, you'll see the hibernate option under _System_ (or `Super + Esc`), and then you can see if it works consistently on your system. If not, you can remove it again by running `hexarchy hibernation remove`.
