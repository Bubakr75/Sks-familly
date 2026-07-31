import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

public final class GenerateWebIcons {
  private static final Color BACKGROUND = new Color(0x05, 0x14, 0x10);

  private GenerateWebIcons() {}

  public static void main(String[] args) throws Exception {
    BufferedImage source = ImageIO.read(new File("assets/icon/app_icon.png"));
    if (source == null) {
      throw new IllegalStateException("Impossible de lire assets/icon/app_icon.png.");
    }

    writeIcon(source, "web/apple-touch-icon.png", 180, 0.82);
    writeIcon(source, "web/icons/Icon-192.png", 192, 0.82);
    writeIcon(source, "web/icons/Icon-512.png", 512, 0.82);
    writeIcon(source, "web/icons/Icon-maskable-192.png", 192, 0.68);
    writeIcon(source, "web/icons/Icon-maskable-512.png", 512, 0.68);
    writeIcon(source, "web/favicon.png", 48, 0.82);
  }

  private static void writeIcon(
      BufferedImage source, String outputPath, int canvasSize, double logoScale)
      throws Exception {
    BufferedImage canvas =
        new BufferedImage(canvasSize, canvasSize, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = canvas.createGraphics();
    graphics.setColor(BACKGROUND);
    graphics.fillRect(0, 0, canvasSize, canvasSize);
    graphics.setRenderingHint(
        RenderingHints.KEY_INTERPOLATION,
        RenderingHints.VALUE_INTERPOLATION_BICUBIC);
    graphics.setRenderingHint(
        RenderingHints.KEY_RENDERING,
        RenderingHints.VALUE_RENDER_QUALITY);

    int logoSize = (int) Math.round(canvasSize * logoScale);
    int offset = (canvasSize - logoSize) / 2;
    double radius = logoSize * 0.28;
    graphics.setClip(
        new RoundRectangle2D.Double(
            offset, offset, logoSize, logoSize, radius, radius));
    graphics.drawImage(source, offset, offset, logoSize, logoSize, null);
    graphics.dispose();

    File output = new File(outputPath);
    File parent = output.getParentFile();
    if (parent != null) {
      parent.mkdirs();
    }
    ImageIO.write(canvas, "png", output);
  }
}
