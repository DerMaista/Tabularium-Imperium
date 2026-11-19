package backend

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
)

// Picker thumbnails: decoding every full-size wallpaper in the UI is serialized on
// Qt's single image thread and takes seconds, so small JPEGs are cached on disk.
const (
	thumbWidth   = 512
	thumbQuality = 85
	// Source pixels averaged per thumbnail pixel along each axis.
	thumbSamples = 4
)

// Formats the standard library decodes; others (webp, bmp) use the original image.
var thumbExtensions = map[string]bool{".jpg": true, ".jpeg": true, ".png": true}

type thumbCache struct {
	mu       sync.Mutex
	inFlight map[string]bool
}

func newThumbCache() *thumbCache {
	return &thumbCache{inFlight: map[string]bool{}}
}

func thumbDir() string {
	dir, err := paths.New("blueshell").CacheDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "thumbs")
}

// thumbPath is the cache file for an image; it changes whenever the image does.
func thumbPath(src string) string {
	if !thumbExtensions[strings.ToLower(filepath.Ext(src))] {
		return ""
	}
	dir := thumbDir()
	if dir == "" {
		return ""
	}
	info, err := os.Stat(src)
	if err != nil || !info.Mode().IsRegular() {
		return ""
	}
	sum := sha1.Sum(fmt.Appendf(nil, "%s\x00%d\x00%d\x00%d", src, info.Size(), info.ModTime().UnixNano(), thumbWidth))
	return filepath.Join(dir, hex.EncodeToString(sum[:])+".jpg")
}

// lookup returns the cached thumbnail for src, or "" if it doesn't exist yet.
func (c *thumbCache) lookup(src string) string {
	path := thumbPath(src)
	if path == "" {
		return ""
	}
	if _, err := os.Stat(path); err != nil {
		return ""
	}
	return path
}

// generate builds the missing thumbnails in the background and calls done if any were made.
func (c *thumbCache) generate(srcs []string, done func()) {
	var todo []string
	c.mu.Lock()
	for _, src := range srcs {
		path := thumbPath(src)
		if path == "" || c.inFlight[path] {
			continue
		}
		if _, err := os.Stat(path); err == nil {
			continue
		}
		c.inFlight[path] = true
		todo = append(todo, src)
	}
	c.mu.Unlock()
	if len(todo) == 0 {
		return
	}

	go func() {
		jobs := make(chan string)
		var wg sync.WaitGroup
		var made atomic.Bool
		workers := min(len(todo), max(1, runtime.NumCPU()/2))
		for range workers {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for src := range jobs {
					path := thumbPath(src)
					if err := writeThumb(src, path); err != nil {
						log.Debugf("thumbs: %s: %v", src, err)
					} else {
						made.Store(true)
					}
					c.mu.Lock()
					delete(c.inFlight, path)
					c.mu.Unlock()
				}
			}()
		}
		for _, src := range todo {
			jobs <- src
		}
		close(jobs)
		wg.Wait()

		if made.Load() && done != nil {
			done()
		}
	}()
}

func writeThumb(src, dst string) error {
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	img, _, err := image.Decode(f)
	f.Close()
	if err != nil {
		return err
	}

	thumb := downscale(img, thumbWidth)

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(dst), ".thumb-*")
	if err != nil {
		return err
	}
	if err := jpeg.Encode(tmp, thumb, &jpeg.Options{Quality: thumbQuality}); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmp.Name())
		return err
	}
	return os.Rename(tmp.Name(), dst)
}

// downscale shrinks img to width (keeping the aspect ratio) by averaging a grid of samples per pixel.
func downscale(img image.Image, width int) image.Image {
	b := img.Bounds()
	sw, sh := b.Dx(), b.Dy()
	if sw <= width {
		return img
	}
	height := max(1, sh*width/sw)
	dst := image.NewRGBA(image.Rect(0, 0, width, height))

	for y := range height {
		for x := range width {
			var r, g, bl, n uint32
			for sy := range thumbSamples {
				py := b.Min.Y + ((y*thumbSamples+sy)*sh+sh/2)/(height*thumbSamples)
				for sx := range thumbSamples {
					px := b.Min.X + ((x*thumbSamples+sx)*sw+sw/2)/(width*thumbSamples)
					cr, cg, cb, _ := img.At(px, py).RGBA()
					r += cr
					g += cg
					bl += cb
					n++
				}
			}
			dst.SetRGBA(x, y, color.RGBA{uint8(r / n >> 8), uint8(g / n >> 8), uint8(bl / n >> 8), 0xff})
		}
	}
	return dst
}
