public class Pixel : Label {
    public bool Value;
    public int X { get; set; }
    public int Y { get; set; }

    public Pixel(int x, int y) {
        this.Size = new Size(100, 100);
        SetValue(false);
        X = x;
        Y = y;
    }

    public bool GetValue() {
        return Value;
    }
    public bool SetValue(bool v) {
        this.Value = v;

        this.BackColor = this.Value ? System.Drawing.Color.Black : System.Drawing.Color.White;

        return this.Value;
    }

    public bool Flip() {
        return SetValue(!GetValue());
    }
}