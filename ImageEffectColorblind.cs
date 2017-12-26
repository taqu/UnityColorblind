using UnityEngine;

[RequireComponent(typeof(Camera))]
public class ImageEffectDaltonize : MonoBehaviour
{
    private const HideFlags DontSave = HideFlags.DontSaveInBuild | HideFlags.DontSaveInEditor;
    private const int NumCategories = 9;

    private string[] labels_ = new string[NumCategories];
    private Material material_;
    private int selected_;

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        Graphics.Blit(src, dst, material_, selected_);
    }

    private void Start()
    {
        Shader shader = Shader.Find("Hidden/Colorblind");
        material_ = new Material(shader);
        material_.hideFlags = DontSave;

        labels_[0] = "Normal";
        labels_[1] = "Protanomaly (low red)";
        labels_[2] = "Deuteranomaly (low green)";
        labels_[3] = "Tritanomaly (low blue)";
        labels_[4] = "Protanopia (no red)";
        labels_[5] = "Deuteranopia (no green)";
        labels_[6] = "Tritanopia (no blue)";
        labels_[7] = "Monochromacy";
        labels_[8] = "Blue cone monochromacy";
    }

    private void OnDestroy()
    {
        if (null != material_)
        {
            Material.DestroyImmediate(material_);
            material_ = null;
        }
    }

    private void OnGUI()
    {
        selected_ = GUI.SelectionGrid(new Rect(10, 10, 200, 200), selected_, labels_, 1);
    }
}
