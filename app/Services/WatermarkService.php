<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class WatermarkService
{
    /**
     * Apply a strong, visible "kreavana" watermark to an image and save it.
     *
     * Strategy:
     * 1. Tiled diagonal watermark text across the entire image
     * 2. Large centered watermark text for unmistakable branding
     * 3. Semi-transparent overlay band across center
     *
     * This makes screenshots and crops commercially useless.
     *
     * @param string $sourcePath Absolute path to the source image
     * @param string $destinationPath Absolute path to save the watermarked image
     * @return bool Success status
     */
    public function applyWatermark(string $sourcePath, string $destinationPath): bool
    {
        if (!extension_loaded('gd')) {
            Log::warning("GD PHP extension is not loaded. Copying original file as fallback without watermark.");
            return copy($sourcePath, $destinationPath);
        }

        try {
            $imageInfo = @getimagesize($sourcePath);
            if (!$imageInfo) {
                Log::error("Unable to read image size/type for: " . $sourcePath);
                return copy($sourcePath, $destinationPath);
            }

            $mime   = $imageInfo['mime'];
            $width  = $imageInfo[0];
            $height = $imageInfo[1];

            // Create image resource based on type
            $image = match ($mime) {
                'image/jpeg', 'image/jpg' => @imagecreatefromjpeg($sourcePath),
                'image/png'               => @imagecreatefrompng($sourcePath),
                'image/webp'              => @imagecreatefromwebp($sourcePath),
                default                   => null,
            };

            if (!$image) {
                Log::warning("Unsupported or unreadable image type: {$mime}. Copying original.");
                return copy($sourcePath, $destinationPath);
            }

            imagealphablending($image, true);
            imagesavealpha($image, true);

            // ─── Layer 1: Tiled diagonal watermark across entire image ───
            $this->applyTiledWatermark($image, $width, $height);

            // ─── Layer 2: Center band overlay ───
            $this->applyCenterBand($image, $width, $height);

            // ─── Layer 3: Large centered watermark text ───
            $this->applyCenterText($image, $width, $height);

            // Ensure the destination directory exists
            $dir = dirname($destinationPath);
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }

            // Save the image
            $success = match ($mime) {
                'image/jpeg', 'image/jpg' => imagejpeg($image, $destinationPath, 85),
                'image/png'               => imagepng($image, $destinationPath, 6),
                'image/webp'              => imagewebp($image, $destinationPath, 80),
                default                   => false,
            };

            imagedestroy($image);
            return $success;

        } catch (\Exception $e) {
            Log::error("Error applying watermark: " . $e->getMessage());
            return copy($sourcePath, $destinationPath);
        }
    }

    /**
     * Layer 1: Tile "kreavana" text across the entire image in a diagonal grid.
     */
    private function applyTiledWatermark(\GdImage $image, int $width, int $height): void
    {
        $watermarkText = "kreavana";
        $textColor     = imagecolorallocatealpha($image, 255, 255, 255, 85);  // semi-transparent white
        $shadowColor   = imagecolorallocatealpha($image, 0, 0, 0, 100);       // subtle black shadow

        $font       = 5; // GD built-in font (largest)
        $fontWidth  = imagefontwidth($font);
        $fontHeight = imagefontheight($font);
        $textLen    = strlen($watermarkText) * $fontWidth;

        // Tighter grid for better coverage
        $xStep = $textLen + 80;
        $yStep = $fontHeight + 60;

        for ($y = 20; $y < $height; $y += $yStep) {
            // Stagger every other row for diagonal effect
            $startX = (intdiv($y, $yStep) % 2 === 0) ? 20 : $xStep / 2;

            for ($x = (int) $startX; $x < $width; $x += $xStep) {
                // Shadow
                imagestring($image, $font, $x + 1, $y + 1, $watermarkText, $shadowColor);
                // Text
                imagestring($image, $font, $x, $y, $watermarkText, $textColor);
            }
        }
    }

    /**
     * Layer 2: Draw a semi-transparent dark band across the center of the image.
     * This ensures the watermark is visible regardless of image content.
     */
    private function applyCenterBand(\GdImage $image, int $width, int $height): void
    {
        $bandHeight = max(50, (int) ($height * 0.08)); // 8% of image height, minimum 50px
        $bandTop    = (int) (($height - $bandHeight) / 2);
        $bandColor  = imagecolorallocatealpha($image, 0, 0, 0, 70); // semi-transparent black

        imagefilledrectangle($image, 0, $bandTop, $width, $bandTop + $bandHeight, $bandColor);
    }

    /**
     * Layer 3: Draw a large centered "kreavana" text over the center band.
     */
    private function applyCenterText(\GdImage $image, int $width, int $height): void
    {
        $watermarkText = "kreavana";
        $font          = 5; // GD built-in largest
        $fontWidth     = imagefontwidth($font);
        $fontHeight    = imagefontheight($font);

        // We repeat the text to span the width, with spacing
        $singleWidth = strlen($watermarkText) * $fontWidth;
        $totalText   = str_repeat($watermarkText . "   ", (int) ceil($width / ($singleWidth + $fontWidth * 3)) + 1);

        $textColor   = imagecolorallocatealpha($image, 255, 255, 255, 50); // more visible white
        $shadowColor = imagecolorallocatealpha($image, 0, 0, 0, 60);

        $y = (int) (($height - $fontHeight) / 2);

        // Shadow
        imagestring($image, $font, 1, $y + 1, $totalText, $shadowColor);
        // Text
        imagestring($image, $font, 0, $y, $totalText, $textColor);

        // Second row offset slightly
        imagestring($image, $font, (int) ($singleWidth / 2) + 1, $y + $fontHeight + 6, $totalText, $shadowColor);
        imagestring($image, $font, (int) ($singleWidth / 2), $y + $fontHeight + 5, $totalText, $textColor);
    }
}
