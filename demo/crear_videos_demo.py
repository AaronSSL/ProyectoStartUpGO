"""Crea los videos de entrevista FICTICIOS de la demo en public/demo/entrevistas/ (voz sintética de Windows sobre un
cuadro fijo, con ffmpeg). Mismo método que herramientas/crear_ejemplos.py de Palomar Talent, con guiones pensados para
los avisos de la demo de CV UP. Nadie real aparece ni habla en ellos.

Uso (Windows, con ffmpeg en el PATH y Pillow instalado):
    python demo/crear_videos_demo.py
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
SALIDA = RAIZ / "public" / "demo" / "entrevistas"

# archivo -> (rótulo, guion). Tres niveles para el mismo aviso, para que el ranking de entrevistas se note.
ENTREVISTAS = {
    "analista_datos_1.mp4": ("Analista de Datos · ejemplo 1", (
        "Buenas tardes, muchas gracias por la invitación. Soy bachiller en Ingeniería Industrial y tengo tres años de "
        "experiencia como analista de datos en una empresa de retail. Todos los días hago consultas en SQL, con joins y "
        "funciones de ventana, sobre el almacén de datos de ventas. Construí los dashboards de indicadores comerciales en "
        "Power BI que hoy usan las jefaturas, y manejo Excel avanzado, con tablas dinámicas y Power Query, para consolidar "
        "información de distintas fuentes. Además automaticé con Python y pandas el reporte de cierre mensual, que antes "
        "tomaba dos días y ahora se genera en una hora. Lo que más disfruto es presentar los hallazgos a las gerencias de "
        "forma clara, con recomendaciones concretas.")),
    "analista_datos_2.mp4": ("Analista de Datos · ejemplo 2", (
        "Hola, buenas tardes. Este, soy egresado de Economía y tengo un año trabajando en el área de planeamiento. O sea, "
        "mi trabajo principal es armar reportes de gestión en Excel, con tablas dinámicas y algunos gráficos. Bueno, SQL lo "
        "he usado a nivel intermedio, consultas con agrupaciones, este, más que nada para sacar bases. Power BI lo estoy "
        "aprendiendo en un curso, digamos que ya hice mis primeros tableros. Python todavía no lo manejo, pero me interesa "
        "mucho aprenderlo para automatizar los reportes.")),
    "analista_datos_3.mp4": ("Analista de Datos · ejemplo 3", (
        "Buenas tardes. Bueno, la verdad mi experiencia es en ventas, he trabajado como promotor y luego como cajero en una "
        "tienda. No tengo experiencia en análisis de datos, pero aprendo rápido. Excel lo uso a nivel básico, para hacer "
        "listas. Nunca he usado SQL ni Power BI. Me interesa el puesto porque quiero cambiar de rubro y crecer en una "
        "empresa grande.")),
    "atencion_cliente_1.mp4": ("Atención al Cliente · ejemplo", (
        "Buenos días. Estudié Administración de Empresas y tengo dos años como ejecutiva de atención al cliente en una "
        "empresa de telecomunicaciones. Atendía consultas y reclamos por teléfono, chat y redes sociales, y registraba cada "
        "caso en el CRM hasta cerrarlo. Manejo Excel a nivel intermedio para mis reportes de atención. Para mí lo más "
        "importante es escuchar con empatía y darle al cliente una solución real, no solo una respuesta. El año pasado mi "
        "equipo redujo los reclamos repetidos gracias a una mejora que propuse en el registro de casos.")),
}


def cuadro_video(rotulo, png):
    """Cuadro fijo: silueta neutra y rótulo, para que se note que es una entrevista ficticia."""
    from PIL import Image, ImageDraw, ImageFont
    w, h = 1280, 720
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):   # degradado azul de CV UP
        t = y / h
        d.line([(0, y), (w, y)], fill=(int(23 + 10 * t), int(42 + 16 * t), int(77 + 26 * t)))
    d.rectangle([0, int(h * 0.78), w, h], fill=(26, 40, 74))
    cx = w // 2
    d.ellipse([cx - 230, 330, cx + 230, 760], fill=(61, 92, 140))
    d.ellipse([cx - 95, 150, cx + 95, 350], fill=(123, 191, 200))
    try:
        f1, f2 = ImageFont.truetype("segoeuib.ttf", 34), ImageFont.truetype("segoeui.ttf", 24)
    except OSError:
        f1 = f2 = ImageFont.load_default()
    d.rounded_rectangle([36, h - 118, 700, h - 34], radius=10, fill=(17, 26, 48))
    d.text((58, h - 110), rotulo, font=f1, fill=(249, 250, 251))
    d.text((58, h - 68), "CV UP · entrevista de ejemplo · voz sintética", font=f2, fill=(156, 180, 210))
    img.save(png)


def voz_a_wav(texto, wav):
    """Voz sintética en español con System.Speech de Windows."""
    ps = ("Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
          "$v = $s.GetInstalledVoices() | ? { $_.VoiceInfo.Culture.Name -like 'es*' } | select -First 1; "
          "if ($v) { $s.SelectVoice($v.VoiceInfo.Name) }; $s.Rate = 0; "
          f"$s.SetOutputToWaveFile('{wav}'); $s.Speak([IO.File]::ReadAllText('{wav}.txt')); $s.Dispose()")
    Path(f"{wav}.txt").write_text(texto, encoding="utf-8")
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)


def main():
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("Falta ffmpeg en el PATH")
    SALIDA.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for nombre, (rotulo, texto) in ENTREVISTAS.items():
            base = Path(tmp) / Path(nombre).stem
            voz_a_wav(texto, f"{base}.wav")
            cuadro_video(rotulo, f"{base}.png")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-loop", "1", "-framerate", "15", "-i", f"{base}.png",
                            "-i", f"{base}.wav", "-shortest", "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p",
                            "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(SALIDA / nombre)], check=True)
            print("✓", nombre, f"{(SALIDA / nombre).stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
