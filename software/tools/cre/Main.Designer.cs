namespace cre;

using System.Globalization;
using System.Text;

partial class Main
{
    private static string FILENAME = @"C:\users\Korey\Desktop\romdata.txt";
    private static string ASSEMBLY_OUT = @"C:\users\Korey\Desktop\font.asm";
    private static string BYTE_FILE = @"C:\users\Korey\Desktop\ascii.rom";

    private System.ComponentModel.IContainer components = null;
    private NumericUpDown offset = null;
    private NumericUpDown group = null;
    private Pixel[,] pixelGrid = new Pixel[8, 16]; 
    private Label[] pixelValues = new Label[16];
    private byte[] fileData;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    private void InitializeComponent()
    {
        // Load file data
        var lineData = System.IO.File.ReadAllLines(FILENAME);
        fileData = new byte[lineData.Length];
        //fileData = new byte[lineData.Length / 2];
        for(int i = 0; i < lineData.Length; i++) {
            //if (i % 2 == 0)
                fileData[i] = byte.Parse(lineData[i].Substring(2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        }

        this.components = new System.ComponentModel.Container();
        this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        this.ClientSize = new System.Drawing.Size(1200, 1800);
        this.Text = "Character ROM Editor";

        // Initalize stepping controls
        offset = new NumericUpDown() {
            Value = 0,
            Minimum = 0,
            Maximum = 255,
            Increment = 1,
            Location = new Point(10,10)
        };
        group = new NumericUpDown() {
            Value = 0,
            Minimum = 0,
            Maximum = 600000,
            Increment = 1,
            Location = new Point(200,10)
        };

        offset.ValueChanged += UpdatePixelGrid;
        group.ValueChanged += UpdatePixelGrid;

        Button saveButton = new Button() {
            Text = "&Save",
            Width = 100,
            Height = 40,
            Location = new Point(350,10)
        };

        Button asmButton = new Button() {
            Text = "&Assembly",
            Width = 100,
            Height = 40,
            Location = new Point(480,10)
        };

        Button byteButton = new Button() {
            Text = "&Byte",
            Width = 100,
            Height = 40,
            Location = new Point(620,10)
        };

        asmButton.Click += SaveAssemblyData;
        saveButton.Click += SaveData;
        byteButton.Click += SaveBytes;

        this.Controls.Add(offset);
        this.Controls.Add(group);
        this.Controls.Add(saveButton);
        this.Controls.Add(asmButton);
        this.Controls.Add(byteButton);

        // Initalize pixel grid
        for (int y = 0; y < 16; y++) {
            for (int x = 0; x < 8; x++) {
                Pixel p = new Pixel(x, y);
                pixelGrid[x, y] = p;

                p.SetValue(((x + 1) + (y + 1)) % 2 != 0);
                p.Location = new Point(100 * (1 + x), 100 * (1 + y));
                p.Click += FlipPixel;

                this.Controls.Add(p);
            }
        }

        // Initialize pixel value grid
        for (int y = 0; y < 16; y++) {
            pixelValues[y] = new Label() {
                Text = "0x00",
                Height = 100,
                TextAlign = ContentAlignment.MiddleCenter,
                Location = new Point(900, 100 * (1 + y))
            };

            this.Controls.Add(pixelValues[y]);
        }

        // Center form on screen
        this.StartPosition = FormStartPosition.CenterScreen;

        RenderPixelGrid();
    }

    private void FlipPixel(Object sender, EventArgs e) {
        Pixel p = (Pixel)sender;
        int position = Convert.ToInt16(offset.Value) + Convert.ToInt32(group.Value * 16);
        var newBitValue = p.Flip();
        int bitIndex = Math.Abs(p.X - 7);       // Reverse bits

        var byteValue = (int)fileData[position + p.Y];

        if (newBitValue)
            byteValue |= (1 << bitIndex);
        else
            byteValue &= ~(1 << bitIndex);

        fileData[position + p.Y ] = (byte)byteValue;

        RenderPixelGrid();
    }

    private void SaveAssemblyData(Object sender, EventArgs e) {
        int index = 0;
        int asciiCode = 0;
        var currentCharacter = new byte[16];
        string allText = "";

        for(int i = 0; i < fileData.Length; i++) {
            if (index == 16) {
                var asciiLetter = Convert.ToChar(asciiCode);
                if (asciiCode < 32 || asciiCode > 127)
                    asciiLetter = ' ';

                StringBuilder outLine = new StringBuilder($"; ASCII Code {asciiCode} - {asciiLetter}");
                outLine.AppendLine();
                outLine.Append("  .byte");

                for (int z = 0; z < 16; z++) {
                    outLine.Append(" $" + BitConverter.ToString(new byte[] { currentCharacter[z] }));
                }
                outLine.AppendLine();
                allText += outLine.ToString();
                index = 0;
                asciiCode++;
            }
            currentCharacter[index] = fileData[i];
            index++;
        }

        System.IO.File.WriteAllText(ASSEMBLY_OUT, allText);
    }

    private void UpdatePixelGrid(Object sender, EventArgs e) {
        RenderPixelGrid();
    }

    private void SaveBytes(Object sender, EventArgs e) {
        var byteData = new byte[fileData.Length * 4];

        // Write the normal font set
        Array.Copy(fileData, 0, byteData, 0, 4096);

        // Write the cursor (reverse) font set
        Array.Copy(fileData, 0, byteData, 4096, 4096);

        // Write the underline font set
        Array.Copy(fileData, 0, byteData, 8192, 4096);

        // Write the reverse and underline font set
        Array.Copy(fileData, 0, byteData, 12288, 4096);

        // Write the bytes to a file
        System.IO.File.WriteAllBytes(BYTE_FILE, byteData);
    }

    private void SaveData(Object sender, EventArgs e) {
        var lineData = new string[fileData.Length];
        for(int i = 0; i < fileData.Length; i++) {
            lineData[i] = "0x" + BitConverter.ToString(new byte[] { fileData[i] });
        }

        System.IO.File.WriteAllLines(FILENAME, lineData);
    }

    private void RenderPixelGrid() {
        int position = Convert.ToInt16(offset.Value) + Convert.ToInt32(group.Value * 16);

        for(int y = 0; y < 16; y++) {
            var byteValue = fileData[position + y];
            for(int x = 0; x < 8; x++) {
                int bitIndex = Math.Abs(x - 7);     // Reverse bits
                pixelGrid[x, y].SetValue((byteValue & (1 << bitIndex)) != 0);
            }
            pixelValues[y].Text = "0x" + BitConverter.ToString(new byte[] { byteValue });
        }

    }

    #endregion
}
