using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

//This script requires you to have setup your animator with 3 parameters, "InputMagnitude", "InputX", "InputZ"
//With a blend tree to control the inputmagnitude and allow blending between animations.
//Also you need to shoose Firepoint, targets > 1, Aim image from canvas and 2 target markers and camera.
[RequireComponent(typeof(CharacterController))]
public class ArcherInput : MonoBehaviour
{
    public float velocity = 9;
    [Space]

    public float InputX;
    public float InputZ;
    public Vector3 desiredMoveDirection;
    public bool blockRotationPlayer;
    public float desiredRotationSpeed = 0.1f;
    public Animator anim;
    public float Speed;
    public float allowPlayerRotation = 0.1f;
    public Camera cam;
    public CharacterController controller;
    public bool isGrounded;

    [Space]
    [Header("Animation Smoothing")]
    [Range(0, 1f)]
    public float HorizontalAnimSmoothTime = 0.2f;
    [Range(0, 1f)]
    public float VerticalAnimTime = 0.2f;
    [Range(0, 1f)]
    public float StartAnimTime = 0.3f;
    [Range(0, 1f)]
    public float StopAnimTime = 0.15f;

    private float verticalVel;
    private Vector3 moveVector;
    public bool canMove;

    [Space]
    [Header("Effects")]
    public GameObject[] Prefabs;
    public GameObject[] PrefabsCast;
    private ParticleSystem Effect;
    public float[] castingTime; //If 0 - can loop, if > 0 - one shot time
    public LayerMask collidingLayer = ~0; //Target marker can only collide with scene layer

    [Space]
    [Header("Canvas")]
    public Image aim;
    public Vector2 uiOffset;
    public List<Transform> screenTargets = new List<Transform>();
    private Transform target;
    private bool activeTarger = false;
    public Transform FirePoint;
    public float fireRate = 0.1f;
    private bool rotateState = false;

    void Start()
    {
        anim = this.GetComponent<Animator>();
        cam = Camera.main;
        controller = this.GetComponent<CharacterController>();
        target = screenTargets[targetIndex()];
    }

    void Update()
    {
        UserInterface();
        //Disable moving and skills if alrerady using one

        if (!canMove)
            return;

        target = screenTargets[targetIndex()];

        if (Input.GetMouseButtonDown(0) && activeTarger)
        {
            if (rotateState == false)
            {
                StartCoroutine(RotateToTarget(fireRate, target.position)); 
            }
            foreach (var effect in PrefabsCast)
            {
                Effect = effect.GetComponent<ParticleSystem>();
                Effect.Play();
            }
            Effect = PrefabsCast[0].GetComponent<ParticleSystem>();
            Effect.Play();
            StartCoroutine(Attack(0));
        }

        InputMagnitude();

        //If you don't need the character grounded then get rid of this part.
        isGrounded = controller.isGrounded;
        if (isGrounded)
        {
            verticalVel = 0;
        }
        else
        {
            verticalVel -= 1f * Time.deltaTime;
        }
        moveVector = new Vector3(0, verticalVel, 0);
        controller.Move(moveVector);
    }

    public IEnumerator Attack(int EffectNumber)
    {
        //Block moving after using the skill
        canMove = false;
        SetAnimZero();
        while (true)
        {
            anim.SetTrigger("Attack1");
            yield return new WaitForSeconds(castingTime[EffectNumber]);
            GameObject projectile = Instantiate(Prefabs[0], FirePoint.position, FirePoint.rotation);
            projectile.GetComponent<TargetProjectile>().UpdateTarget(target, (Vector3)uiOffset);
            yield return new WaitForSeconds(0.2f);
            canMove = true;
            yield break;
        }
    }

    //For standing after skill animation
    private void SetAnimZero()
    {
        anim.SetFloat("InputMagnitude", 0);
        anim.SetFloat("InputZ", 0);
        anim.SetFloat("InputX", 0);
    }

    //Rotate player to target when attack
    public IEnumerator RotateToTarget(float rotatingTime, Vector3 targetPoint)
    {
        rotateState = true;
        float delay = rotatingTime;
        var lookPos = target.position - transform.position;
        lookPos.y = 0;
        var rotation = Quaternion.LookRotation(lookPos);
        while (true)
        {
            delay -= Time.deltaTime;
            if (delay <= 0 || transform.rotation == rotation)
            {
                rotateState = false;
                yield break;
            }
            else
            {
                transform.rotation = Quaternion.Lerp(transform.rotation, rotation, Time.deltaTime * 20);
            }
            yield return null;
        }
    }

    void PlayerMoveAndRotation()
    {
        InputX = Input.GetAxis("Horizontal");
        InputZ = Input.GetAxis("Vertical");

        var camera = Camera.main;
        var forward = cam.transform.forward;
        var right = cam.transform.right;

        forward.y = 0f;
        right.y = 0f;

        forward.Normalize();
        right.Normalize();

        //Movement vector
        desiredMoveDirection = forward * InputZ + right * InputX;

        //Character diagonal movement faster fix
        desiredMoveDirection.Normalize();

        if (blockRotationPlayer == false)
        {
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(desiredMoveDirection), desiredRotationSpeed);
            controller.Move(desiredMoveDirection * Time.deltaTime * velocity);
        }
    }

    void InputMagnitude()
    {
        //Calculate Input Vectors
        InputX = Input.GetAxis("Horizontal");
        InputZ = Input.GetAxis("Vertical");

        anim.SetFloat("InputZ", InputZ, VerticalAnimTime, Time.deltaTime * 2f);
        anim.SetFloat("InputX", InputX, HorizontalAnimSmoothTime, Time.deltaTime * 2f);

        //Calculate the Input Magnitude
        Speed = new Vector2(InputX, InputZ).sqrMagnitude;

        //Physically move player
        if (Speed > allowPlayerRotation)
        {
            anim.SetFloat("InputMagnitude", Speed, StartAnimTime, Time.deltaTime);
            PlayerMoveAndRotation();
        }
        else if (Speed < allowPlayerRotation)
        {
            anim.SetFloat("InputMagnitude", Speed, StopAnimTime, Time.deltaTime);
        }
    }

    private void UserInterface()
    {
        Vector3 screenCenter = new Vector3(Screen.width, Screen.height, 0) / 2;
        Vector3 screenPos = Camera.main.WorldToScreenPoint(target.position + (Vector3)uiOffset);
        Vector3 CornerDistance = screenPos - screenCenter;
        Vector3 absCornerDistance = new Vector3(Mathf.Abs(CornerDistance.x), Mathf.Abs(CornerDistance.y), Mathf.Abs(CornerDistance.z));

        if (absCornerDistance.x < screenCenter.x / 3 && absCornerDistance.y < screenCenter.y / 3 && screenPos.x > 0 && screenPos.y > 0 && screenPos.z > 0 //If target is in the middle of the screen
            && !Physics.Linecast(transform.position + (Vector3)uiOffset, target.position + (Vector3)uiOffset * 2, collidingLayer)) //If player can see the target
        {
            aim.transform.position = Vector3.MoveTowards(aim.transform.position, screenPos, Time.deltaTime * 3000);
            if (!activeTarger)
                activeTarger = true;
        }
        else
        {
            aim.transform.position = Vector3.MoveTowards(aim.transform.position, screenCenter, Time.deltaTime * 3000);
            if (activeTarger)
                activeTarger = false;
        }
    }

    public int targetIndex()
    {
        float[] distances = new float[screenTargets.Count];

        for (int i = 0; i < screenTargets.Count; i++)
        {
            distances[i] = Vector2.Distance(Camera.main.WorldToScreenPoint(screenTargets[i].position), new Vector2(Screen.width / 2, Screen.height / 2));
        }

        float minDistance = Mathf.Min(distances);
        int index = 0;

        for (int i = 0; i < distances.Length; i++)
        {
            if (minDistance == distances[i])
                index = i;
        }
        return index;
    }
}
