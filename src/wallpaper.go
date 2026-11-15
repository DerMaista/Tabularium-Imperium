package main

import (
	"fmt"
	"path/filepath"
	"strings"

	"blueshell/internal/backend"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/spf13/cobra"
)

func wallpaperCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:          "wallpaper",
		SilenceUsage: true,
		Short:        "Switch between the sigil wallpaper and an image",
		Long: "The wallpaper is either the blueprint grid with the sigil (mode sigil)\n" +
			"or an image (mode image). Image mode without a readable image shows the\n" +
			"sigil.\n\n" +
			"Every theme has its own set of wallpapers: the \"wallpaper\" (default) and\n" +
			"\"wallpapers\" keys of its Chromarium theme file, plus the images in\n" +
			"~/.config/tabularium-imperium/wallpapers/<theme>/ (wallpaper.dir).\n" +
			"What you pick is remembered per theme and comes back when you switch to\n" +
			"it. `blueshell sigil toggle` opens the picker, which shows both.\n\n" +
			"set and mode work without a running shell too; the change is picked up\n" +
			"when it starts. With no argument, prints the current state.",
		Example: "  blueshell wallpaper mode toggle\n" +
			"  blueshell wallpaper list\n" +
			"  blueshell wallpaper set ~/Pictures/nebula.png\n" +
			"  blueshell wallpaper clear",
		Args: cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			socketPath, err := resolveSocket()
			if err != nil {
				mode, image := backend.ReadWallpaperState()
				printWallpaper(map[string]any{"mode": mode, "image": image})
				return nil
			}
			client, err := ipc.Dial(socketPath)
			if err != nil {
				return err
			}
			defer client.Close()
			result, err := callBackend(client, "wallpaper.current", nil)
			if err != nil {
				return err
			}
			printWallpaper(result)
			return nil
		},
	}

	setImage := func(path string) error {
		if path != "" && !strings.HasPrefix(path, "~") && !strings.HasPrefix(path, "$") && !filepath.IsAbs(path) {
			abs, err := filepath.Abs(path)
			if err != nil {
				return err
			}
			path = abs
		}
		if _, err := resolveSocket(); err != nil {
			if err := backend.WriteWallpaperImage(path); err != nil {
				return err
			}
			mode, image := backend.ReadWallpaperState()
			printWallpaper(map[string]any{"mode": mode, "image": image})
			return nil
		}
		return withBackend(func(client *ipc.Client) error {
			result, err := callBackend(client, "wallpaper.set", map[string]any{"path": path})
			if err != nil {
				return err
			}
			printWallpaper(result)
			return nil
		})
	}

	setMode := func(mode string) error {
		if _, err := resolveSocket(); err != nil {
			if _, err := backend.WriteWallpaperMode(mode); err != nil {
				return err
			}
			mode, image := backend.ReadWallpaperState()
			printWallpaper(map[string]any{"mode": mode, "image": image})
			return nil
		}
		return withBackend(func(client *ipc.Client) error {
			result, err := callBackend(client, "wallpaper.mode", map[string]any{"mode": mode})
			if err != nil {
				return err
			}
			printWallpaper(result)
			return nil
		})
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:          "list",
			Short:        "List the current theme's wallpapers",
			SilenceUsage: true,
			Args:         cobra.NoArgs,
			RunE: func(*cobra.Command, []string) error {
				return withBackend(func(client *ipc.Client) error {
					result, err := callBackend(client, "wallpaper.list", nil)
					if err != nil {
						return err
					}
					printWallpaperList(result)
					return nil
				})
			},
		},
		&cobra.Command{
			Use:          "set <path>",
			Short:        "Set the image shown in image mode (an empty path clears it)",
			SilenceUsage: true,
			Args:         cobra.ExactArgs(1),
			RunE: func(_ *cobra.Command, args []string) error {
				return setImage(args[0])
			},
		},
		&cobra.Command{
			Use:          "clear",
			Short:        "Forget the image; image mode then shows the sigil",
			SilenceUsage: true,
			Args:         cobra.NoArgs,
			RunE: func(*cobra.Command, []string) error {
				return setImage("")
			},
		},
		&cobra.Command{
			Use:          "mode <sigil|image|toggle>",
			Short:        "Show the sigil and blueprint grid, or the image",
			SilenceUsage: true,
			Args:         cobra.ExactArgs(1),
			ValidArgs:    []string{backend.WallpaperModeSigil, backend.WallpaperModeImage, "toggle"},
			RunE: func(_ *cobra.Command, args []string) error {
				return setMode(args[0])
			},
		},
		&cobra.Command{
			Use:          "toggle",
			Short:        "Flip between sigil and image mode, for a keybind",
			SilenceUsage: true,
			Args:         cobra.NoArgs,
			RunE: func(*cobra.Command, []string) error {
				return setMode("toggle")
			},
		},
	)

	return cmd
}

func printWallpaperList(result map[string]any) {
	theme, _ := result["theme"].(string)
	image, _ := result["image"].(string)
	showing, _ := result["showing"].(string)
	list, _ := result["wallpapers"].([]any)

	if len(list) == 0 {
		fmt.Printf("no wallpapers for theme %q — add \"wallpapers\" to its theme file or put images in %v\n",
			theme, result["dir"])
		return
	}
	for _, entry := range list {
		wp, ok := entry.(map[string]any)
		if !ok {
			continue
		}
		path, _ := wp["path"].(string)
		marker := " "
		if path == image {
			marker = "-"
			if showing == backend.WallpaperModeImage {
				marker = "*"
			}
		}
		suffix := ""
		if isDefault, _ := wp["default"].(bool); isDefault {
			suffix = "  (default)"
		}
		fmt.Printf("%s %s%s\n", marker, path, suffix)
	}
}

func printWallpaper(state map[string]any) {
	mode, _ := state["mode"].(string)
	image, _ := state["image"].(string)
	if image == "" {
		image = "(none)"
	}
	line := fmt.Sprintf("mode %s, image %s", mode, image)
	if showing, _ := state["showing"].(string); showing != "" && showing != mode {
		if image == "(none)" {
			line += " — showing the sigil (no image for this theme)"
		} else {
			line += " — showing the sigil (image not readable)"
		}
	}
	if theme, _ := state["theme"].(string); theme != "" {
		line += ", theme " + theme
	}
	fmt.Println(line)
}
